package nl.moonlight.measure

import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** The one group everyone on Android joins (trial; no group choice in the app). */
const val GROUP_CODE = "675D89"

class RemoteError(val status: Int, val body: String) : IOException("HTTP $status: $body") {
    val nameTaken get() = body.contains("name taken")
}

/**
 * Supabase over plain HTTPS: anonymous sign-in, then the functions from supabase/migrations
 * (join_group, group_data, set_reaction, update_goal, leave_group). Same calls as the iPhone app.
 * Blocking; call from a background thread.
 */
class Remote(private val prefs: Prefs) {

    /** True once this phone had to sign in as a new anonymous user (first start or lost sign-in). */
    var isNewUser = false
        private set

    private val base get() = BuildConfig.SUPABASE_URL.trimEnd('/')

    private fun request(path: String, body: String, bearer: String?): Pair<Int, String> {
        val conn = URL(base + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 15_000
            conn.readTimeout = 30_000
            conn.doOutput = true
            conn.setRequestProperty("apikey", BuildConfig.SUPABASE_KEY)
            conn.setRequestProperty("Authorization", "Bearer " + (bearer ?: BuildConfig.SUPABASE_KEY))
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: ""
            return code to text
        } finally {
            conn.disconnect()
        }
    }

    private fun storeSession(text: String) {
        val j = JSONObject(text)
        prefs.accessToken = j.getString("access_token")
        prefs.refreshToken = j.getString("refresh_token")
        prefs.tokenExpiresAt = System.currentTimeMillis() + (j.optLong("expires_in", 3600) - 60) * 1000
    }

    /** A valid access token: the stored one, a refreshed one, or a new anonymous user. */
    private fun token(): String {
        if (prefs.accessToken.isNotEmpty() && prefs.tokenExpiresAt > System.currentTimeMillis()) return prefs.accessToken
        if (prefs.refreshToken.isNotEmpty()) {
            val (code, text) = request("/auth/v1/token?grant_type=refresh_token",
                JSONObject().put("refresh_token", prefs.refreshToken).toString(), null)
            if (code in 200..299) {
                storeSession(text)
                return prefs.accessToken
            }
        }
        val (code, text) = request("/auth/v1/signup", """{"data":{}}""", null) // anonymous sign-in
        if (code !in 200..299) throw RemoteError(code, text)
        storeSession(text)
        isNewUser = true
        return prefs.accessToken
    }

    private fun rpc(name: String, params: JSONObject = JSONObject()): String {
        val (code, text) = request("/rest/v1/rpc/$name", params.toString(), token())
        if (code !in 200..299) throw RemoteError(code, text)
        return text
    }

    /** Joins the trial group; returns my participant id. */
    fun join(name: String, goal: String, takeover: Boolean): String {
        val text = rpc("join_group", JSONObject()
            .put("p_code", GROUP_CODE).put("p_name", name).put("p_goal", goal)
            .put("p_platform", "android").put("p_takeover", takeover))
        return text.trim().trim('"')
    }

    /** Raw group data, or null if this sign-in isn't in a group. */
    fun groupData(): JSONObject? {
        val text = rpc("group_data").trim()
        if (text.isEmpty() || text == "null") return null
        return JSONObject(text)
    }

    fun setReaction(target: String, night: String, emoji: String?) {
        rpc("set_reaction", JSONObject().put("p_target", target).put("p_night", night)
            .put("p_emoji", emoji ?: JSONObject.NULL))
    }

    fun updateGoal(goal: String) {
        rpc("update_goal", JSONObject().put("p_goal", goal))
    }

    fun leaveGroup() {
        rpc("leave_group")
    }
}
