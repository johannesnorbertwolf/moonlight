// App state: who I am, the loaded group, and the actions the screens trigger.
package nl.moonlight.measure

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.LocalTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

object AppState {
    private lateinit var appContext: Context
    private lateinit var prefs: Prefs
    private lateinit var remote: Remote
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val loadLock = Mutex()

    var lang by mutableStateOf("en")
    var onboarded by mutableStateOf(false)
    var name by mutableStateOf("")
    var goal by mutableStateOf("21:00")
    var group by mutableStateOf<GroupModel?>(null)
    var loadError by mutableStateOf<String?>(null)
    var toast by mutableStateOf<String?>(null)
    var lastStatus by mutableStateOf("")

    fun init(context: Context) {
        if (::appContext.isInitialized) return
        appContext = context.applicationContext
        prefs = Prefs(appContext)
        remote = Remote(prefs)
        lang = prefs.lang.ifEmpty { if (Locale.getDefault().language == "nl") "nl" else "en" }
        onboarded = prefs.onboarded && prefs.participant.isNotEmpty()
        name = prefs.name
        goal = prefs.goalStart.toString()
        lastStatus = prefs.lastStatus
    }

    fun setLanguage(l: String) {
        lang = l
        prefs.lang = l
    }

    // ---------------------------------------------------------------- onboarding

    /** Joins the trial group. Throws [RemoteError] with nameTaken if someone else has the name. */
    suspend fun join(newName: String, newGoal: String, takeover: Boolean) = withContext(Dispatchers.IO) {
        val pid = remote.join(newName, newGoal, takeover)
        if (prefs.participant != pid) prefs.uploadedUntil = 0L // new id: send last nights again
        prefs.participant = pid
        prefs.name = newName
        prefs.goalStart = LocalTime.parse(newGoal)
        withContext(Dispatchers.Main) {
            name = newName
            goal = newGoal
        }
    }

    fun finishOnboarding() {
        prefs.onboarded = true
        onboarded = true
        NightlyWorker.schedule(appContext)
        MorningReminder.schedule(appContext)
        refresh()
    }

    // ---------------------------------------------------------------- loading

    /** Measures and uploads the last nights (if allowed), then loads the group. */
    fun refresh() {
        scope.launch {
            measureNow(quiet = true)
            load()
        }
    }

    suspend fun load() = loadLock.withLock {
        try {
            val data = withContext(Dispatchers.IO) {
                var d = remote.groupData()
                if (d == null && prefs.name.isNotEmpty() && remote.isNewUser) {
                    // Joined before but the anonymous sign-in is gone: join again with the same name,
                    // which takes over the same participant.
                    prefs.participant = remote.join(prefs.name, prefs.goalStart.toString(), takeover = true)
                    d = remote.groupData()
                }
                d
            }
            if (data == null) {
                // Signed in but in no group (removed): back to the start.
                resetLocal()
                return@withLock
            }
            val me = data.getString("me")
            if (prefs.participant != me) prefs.participant = me
            group = GroupModel.from(data)
            loadError = null
        } catch (e: Exception) {
            if (group == null) loadError = t("error.load")
        }
    }

    /** Measures the last two nights and uploads them. Returns false if usage access is missing. */
    suspend fun measureNow(quiet: Boolean = false): Boolean {
        if (prefs.participant.isEmpty() || !UsageReader.hasUsageAccess(appContext)) return false
        val status = withContext(Dispatchers.IO) {
            try {
                NightlyWorker.measureAndUpload(appContext)
                t("settings.and.uploaded", mapOf("time" to ZonedDateTime.now().format(DateTimeFormatter.ofPattern("EEE HH:mm", locale()))))
            } catch (e: Exception) {
                t("settings.and.failed", mapOf("error" to (e.message ?: "?")))
            }
        }
        prefs.lastStatus = status
        lastStatus = status
        if (!quiet) toast = status
        return true
    }

    // ---------------------------------------------------------------- actions

    fun react(member: Member, night: String, emoji: String) {
        val g = group ?: return
        val mine = g.reactionsFor(member, night).second
        val next = if (mine == emoji) null else emoji
        // Show it right away, then save.
        val others = g.reactions.filterNot { it.target == member.id && it.night == night && it.from == g.meId }
        group = g.copy(reactions = if (next != null) others + Reaction(member.id, night, g.meId, next) else others)
        scope.launch {
            try {
                withContext(Dispatchers.IO) { remote.setReaction(member.id, night, next) }
            } catch (e: Exception) {
                toast = t("react.failed")
                load()
            }
        }
    }

    fun updateGoal(newGoal: String) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) { remote.updateGoal(newGoal) }
            } catch (e: Exception) {
                toast = t("onb.err.network")
                return@launch
            }
            prefs.goalStart = LocalTime.parse(newGoal)
            goal = newGoal
            toast = t("settings.saved")
            load()
        }
    }

    /** "Leave group" deletes my participant, nights and reactions. */
    fun leaveGroup() {
        scope.launch {
            try {
                withContext(Dispatchers.IO) { remote.leaveGroup() }
            } catch (e: Exception) {
                toast = t("onb.err.network")
                return@launch
            }
            resetLocal()
        }
    }

    private fun resetLocal() {
        prefs.clearGroup()
        onboarded = false
        group = null
    }

    fun locale(): Locale = if (lang == "nl") Locale.forLanguageTag("nl-NL") else Locale.UK
}

/** t("key", mapOf("name" to "Sam")) fills {placeholders}, like the web and iPhone apps. */
fun t(key: String, vars: Map<String, Any> = emptyMap()): String {
    var s = (if (AppState.lang == "nl") L10n.nl[key] else null) ?: L10n.en[key] ?: key
    for ((k, v) in vars) s = s.replace("{$k}", v.toString())
    return s
}

val tips: List<String> get() = if (AppState.lang == "nl") L10n.tipsNl else L10n.tipsEn
