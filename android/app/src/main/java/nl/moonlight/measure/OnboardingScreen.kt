// Welcome → name and goal (joins the trial group) → usage access → battery → notifications.
package nl.moonlight.measure

import android.Manifest
import android.annotation.SuppressLint
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.launch
import java.time.LocalTime

@Composable
fun OnboardingScreen() {
    var step by rememberSaveable { mutableIntStateOf(0) }
    BackHandler(enabled = step in 1..1) { step-- }
    Column(
        Modifier.fillMaxSize().background(C.bg).safeDrawingPadding().imePadding()
            .verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        when (step) {
            0 -> Welcome { step = 1 }
            1 -> Profile { step = 2 }
            2 -> UsageAccess { step = 3 }
            3 -> Battery { step = 4 }
            else -> Notifications()
        }
    }
}

@Composable
fun LanguagePicker() {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        listOf("en" to "English", "nl" to "Nederlands").forEachIndexed { i, (code, label) ->
            SegmentedButton(
                selected = AppState.lang == code,
                onClick = { AppState.setLanguage(code) },
                shape = SegmentedButtonDefaults.itemShape(i, 2),
                colors = SegmentedButtonDefaults.colors(activeContainerColor = C.surface2, activeContentColor = C.text1,
                    inactiveContainerColor = C.surface, inactiveContentColor = C.text1),
                icon = {},
            ) { Text(label) }
        }
    }
}

@Composable
private fun ColumnScope.Welcome(next: () -> Unit) {
    Spacer(Modifier.height(48.dp))
    Moon(Bucket.free, 96.dp, Modifier.align(Alignment.CenterHorizontally))
    Spacer(Modifier.height(8.dp))
    Text(t("onb.welcome.title"), color = C.text1, fontSize = 30.sp, fontWeight = FontWeight.Bold,
        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(), lineHeight = 36.sp)
    Text(t("onb.welcome.body"), color = C.text2, fontSize = 16.sp, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(), lineHeight = 22.sp)
    Spacer(Modifier.height(8.dp))
    LanguagePicker()
    PrimaryButton(t("onb.start"), onClick = next)
}

/** A field that opens Android's 24-hour time picker. */
@Composable
fun TimeField(value: String, onChange: (String) -> Unit) {
    val context = LocalContext.current
    Text(value, color = C.text1, fontSize = 22.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.fillMaxWidth()
            .background(C.surface, RoundedCornerShape(12.dp))
            .border(1.dp, C.surface2, RoundedCornerShape(12.dp))
            .clickable {
                val t0 = LocalTime.parse(value)
                TimePickerDialog(context, { _, h, m -> onChange("%02d:%02d".format(h, m)) }, t0.hour, t0.minute, true).show()
            }
            .padding(14.dp))
}

@Composable
private fun ColumnScope.Profile(next: () -> Unit) {
    var name by rememberSaveable { mutableStateOf(AppState.name) }
    var goal by rememberSaveable { mutableStateOf(AppState.goal) }
    var takeover by rememberSaveable { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Title("Moonlight")
    Text(t("onb.name"), color = C.text1, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
    OutlinedTextField(
        value = name,
        onValueChange = { name = it.take(40); takeover = false; error = null },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
        colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = C.surface, unfocusedContainerColor = C.surface,
            focusedBorderColor = C.moon, unfocusedBorderColor = C.surface2, cursorColor = C.moon),
    )
    Muted(t("onb.name.hint"), 13)
    Spacer(Modifier.height(4.dp))
    Text(t("onb.goal"), color = C.text1, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
    TimeField(goal) { goal = it }
    Muted(t("onb.goal.hint"), 13)
    error?.let { Text(it, color = C.warn, fontSize = 14.sp) }
    Spacer(Modifier.height(8.dp))
    if (busy) {
        CircularProgressIndicator(color = C.moon, modifier = Modifier.align(Alignment.CenterHorizontally))
    } else {
        PrimaryButton(t("onb.continue")) {
            val trimmed = name.trim()
            if (trimmed.isEmpty()) { error = t("onb.err.name"); return@PrimaryButton }
            busy = true
            scope.launch {
                try {
                    AppState.join(trimmed, goal, takeover)
                    next()
                } catch (e: RemoteError) {
                    if (e.nameTaken) {
                        takeover = true // a second tap means "that's me"
                        error = t("join.nameTaken", mapOf("group" to "Moonlight"))
                    } else error = t("join.err")
                } catch (e: Exception) {
                    error = t("join.err")
                }
                busy = false
            }
        }
    }
}

@Composable
private fun StepHeader(icon: String, title: String, body: String) {
    Spacer(Modifier.height(40.dp))
    Text(icon, fontSize = 44.sp)
    Title(title)
    Muted(body, 16)
}

@Composable
private fun UsageAccess(next: () -> Unit) {
    val context = LocalContext.current
    var granted by remember { mutableStateOf(UsageReader.hasUsageAccess(context)) }
    var tried by remember { mutableStateOf(false) }
    LifecycleResumeEffect(Unit) {
        granted = UsageReader.hasUsageAccess(context)
        if (granted && tried) next()
        onPauseOrDispose {}
    }
    StepHeader("⏳", t("onb.and.usage.title"), t("onb.and.usage.body"))
    if (tried && !granted) Text(t("onb.and.usage.missing"), color = C.warn, fontSize = 14.sp)
    Spacer(Modifier.height(8.dp))
    if (granted) {
        PrimaryButton(t("onb.continue"), onClick = next)
    } else {
        PrimaryButton(t("onb.and.usage.open")) { tried = true; openUsageAccess(context) }
    }
}

@Composable
private fun Battery(next: () -> Unit) {
    val context = LocalContext.current
    var ok by remember { mutableStateOf(ignoresBatteryLimits(context)) }
    var tried by remember { mutableStateOf(false) }
    LifecycleResumeEffect(Unit) {
        ok = ignoresBatteryLimits(context)
        if (ok && tried) next()
        onPauseOrDispose {}
    }
    StepHeader("🔋", t("onb.and.battery.title"), t("onb.and.battery.body"))
    Spacer(Modifier.height(8.dp))
    if (ok) {
        PrimaryButton(t("onb.continue"), onClick = next)
    } else {
        PrimaryButton(t("onb.and.battery.open")) { tried = true; requestNoBatteryLimits(context) }
        SecondaryButton(t("onb.skip"), onClick = next)
    }
}

@Composable
private fun Notifications() {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        AppState.finishOnboarding()
    }
    StepHeader("🔔", t("onb.notify.title"), t("onb.notify.body"))
    Spacer(Modifier.height(8.dp))
    PrimaryButton(t("onb.notify.allow")) {
        if (Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        else AppState.finishOnboarding()
    }
    SecondaryButton(t("onb.skip")) { AppState.finishOnboarding() }
}

// ---------------------------------------------------------------- system settings

fun openUsageAccess(context: Context) {
    val withPackage = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:" + context.packageName))
    try {
        context.startActivity(withPackage)
    } catch (_: Exception) {
        context.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }
}

fun ignoresBatteryLimits(context: Context): Boolean =
    context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName)

@SuppressLint("BatteryLife") // The morning upload is the app's core job; sideloaded, not on Play.
fun requestNoBatteryLimits(context: Context) {
    try {
        context.startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + context.packageName)))
    } catch (_: Exception) {
        context.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }
}
