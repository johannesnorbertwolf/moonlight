// Today, your night (recap), the group with reactions, history, settings. Same screens as the
// iPhone app (ios/Moonlight/Screens.swift).
package nl.moonlight.measure

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit

private fun longDate(d: LocalDate) = d.format(DateTimeFormatter.ofPattern(
    if (AppState.lang == "nl") "EEEE d MMMM" else "EEEE d MMMM", AppState.locale()))
private fun dayLabel(d: LocalDate) = d.format(DateTimeFormatter.ofPattern("EEE", AppState.locale()))
private fun hhmm(i: java.time.Instant) = i.atZone(Dates.zone).format(DateTimeFormatter.ofPattern("HH:mm"))

// ---------------------------------------------------------------- shell

@Composable
fun MainScreen() {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var recap by rememberSaveable { mutableStateOf(false) }
    BackHandler(enabled = recap || tab != 0) { if (recap) recap = false else tab = 0 }
    LifecycleResumeEffect(Unit) {
        AppState.refresh() // upload last night and load the board whenever the app comes forward
        onPauseOrDispose {}
    }
    Scaffold(
        containerColor = C.bg,
        bottomBar = {
            NavigationBar(containerColor = C.surface) {
                listOf("☾" to "tab.today", "◉" to "tab.group", "▦" to "tab.history", "⚙" to "tab.settings")
                    .forEachIndexed { i, (icon, key) ->
                        NavigationBarItem(
                            selected = tab == i,
                            onClick = { tab = i; recap = false },
                            icon = { Text(icon, fontSize = 20.sp) },
                            label = { Text(t(key)) },
                            colors = NavigationBarItemDefaults.colors(selectedIconColor = C.moon, selectedTextColor = C.moon,
                                indicatorColor = C.surface2, unselectedIconColor = C.text2, unselectedTextColor = C.text2),
                        )
                    }
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize().background(C.bg)) {
            when {
                tab == 0 && recap -> GroupGate { g -> RecapScreen(g) { recap = false; tab = 1 } }
                tab == 0 -> GroupGate { g -> TodayScreen(g) { recap = true } }
                tab == 1 -> GroupGate { g -> GroupScreen(g) }
                tab == 2 -> GroupGate { g -> HistoryScreen(g) }
                else -> SettingsScreen()
            }
        }
        AppState.toast?.let { msg ->
            LaunchedEffect(msg) { delay(2500); AppState.toast = null }
            Box(Modifier.fillMaxSize().padding(pad).padding(bottom = 16.dp), contentAlignment = Alignment.BottomCenter) {
                Text(msg, color = C.text1, modifier = Modifier.background(C.surface2, RoundedCornerShape(50))
                    .padding(horizontal = 16.dp, vertical = 10.dp))
            }
        }
    }
}

/** Loading, error, or the content once the group is there. */
@Composable
fun GroupGate(content: @Composable (GroupModel) -> Unit) {
    val g = AppState.group
    when {
        g != null -> content(g)
        AppState.loadError != null -> Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally) {
            Text(AppState.loadError!!, color = C.text1, textAlign = TextAlign.Center)
            Spacer(Modifier.height(16.dp))
            PrimaryButton(t("retry")) { AppState.refresh() }
        }
        else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = C.moon) }
    }
}

/** Scrollable page with pull-to-refresh. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Page(content: @Composable () -> Unit) {
    var refreshing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    PullToRefreshBox(isRefreshing = refreshing, onRefresh = {
        refreshing = true
        scope.launch { AppState.measureNow(quiet = true); AppState.load(); refreshing = false }
    }) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) { content() }
    }
}

@Composable
fun EmptyNightsCard() {
    Card {
        Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Moon(Bucket.future, 64.dp)
            Text(t("empty.title"), color = C.text1, fontSize = 19.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
            Muted(t("empty.body"))
        }
    }
}

@Composable
private fun Stat(label: String, value: String, modifier: Modifier) {
    Card(modifier) {
        Muted(label, 13)
        Text(value, color = C.text1, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
    }
}

// ---------------------------------------------------------------- today

@Composable
fun TodayScreen(g: GroupModel, openRecap: () -> Unit) {
    val me = g.me
    val now = ZonedDateTime.now()
    val greet = when (now.hour) { in 5..11 -> "today.greeting.morning"; in 12..17 -> "today.greeting.day"; else -> "today.greeting.evening" }
    val active = Dates.inNightWindow(me.goal)
    val until = Dates.minutesUntilWindow(me.goal)
    val night = g.last?.let { me.nights[it.toString()] }
    val nightNo = g.last?.let { ChronoUnit.DAYS.between(g.start, it).toInt() + 1 } ?: 0
    val tip = tips[(now.toLocalDate().toEpochDay() % tips.size).toInt()]
    Page {
        Title(t(greet, mapOf("name" to me.name)))
        Muted(longDate(now.toLocalDate()) + if (nightNo > 0) " · " + t("today.challenge", mapOf("n" to nightNo, "total" to g.nightsTotal)) else "")
        Card {
            if (active) {
                Text(t("today.window.active"), color = C.text1, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
                Muted(t("today.window.active.body"))
            } else {
                Text(t("today.window.upcoming", mapOf("time" to me.goal)), color = C.text1, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
                Muted(t("today.window.in", mapOf("h" to until / 60, "m" to until % 60)))
            }
        }
        if (night != null) {
            Card(Modifier.clickable(onClick = openRecap)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Moon(night.bucket, 44.dp)
                    Column(Modifier.weight(1f)) {
                        Muted(t("today.lastNight"), 13)
                        Text(t("bucket.${night.bucket.name}"), color = C.text1, fontWeight = FontWeight.SemiBold)
                    }
                    Text(t("today.seeRecap") + " ›", color = C.moon, fontSize = 14.sp)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Stat(t("today.streak"), Fmt.nights(g.personalStreak(me)), Modifier.weight(1f))
                Stat(t("today.groupStreak"), Fmt.nights(g.groupStreak()), Modifier.weight(1f))
            }
        } else {
            EmptyNightsCard()
        }
        Card {
            Muted(t("today.tip"), 13)
            Text(tip, color = C.text1)
        }
    }
}

// ---------------------------------------------------------------- recap

@Composable
fun RecapScreen(g: GroupModel, toGroup: () -> Unit) {
    val me = g.me
    val date = g.last ?: return
    val night = me.nights[date.toString()] ?: return
    val len = Dates.windowLength(me.goal).toDouble()
    val used = night.min ?: 0.0
    val share = if (night.bucket == Bucket.missing) 0.0 else maxOf(0.0, 1 - used / len)
    Page {
        Muted(longDate(date))
        Title(t("recap.title"))
        Box(Modifier.fillMaxWidth().padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(160.dp)) {
                val w = 14.dp.toPx()
                val s = Size(size.width - w, size.height - w)
                val o = Offset(w / 2, w / 2)
                drawArc(C.surface2, 0f, 360f, false, o, s, style = Stroke(w))
                drawArc(C.accent, -90f, (360 * share).toFloat(), false, o, s, style = Stroke(w, cap = StrokeCap.Round))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${Math.round(share * 100)}%", color = C.text1, fontSize = 32.sp, fontWeight = FontWeight.SemiBold)
                Muted(t("recap.phoneFree"), 14)
            }
        }
        Muted(t("recap.window", mapOf("start" to me.goal)), 13)
        if (!night.atLeast && night.bucket != Bucket.missing) Timeline(night, len, me.goal)
        Card {
            Text(recapMessage(night, me.goal), color = C.text1)
            if (night.atLeast && night.bucket != Bucket.free) Muted(t("recap.st.note"), 13)
        }
        PrimaryButton(t("recap.toGroup"), onClick = toGroup)
    }
}

private fun recapMessage(n: Night, goal: String): String {
    val used = n.min ?: 0.0
    val time = n.crossedAt?.let(::hhmm) ?: run {
        var total = 0.0
        n.sessions.firstNotNullOfOrNull { s ->
            if (total + s.min >= 2) Dates.clock(goal, s.offset + (2 - total)) else { total += s.min; null }
        }
    }
    return when {
        n.bucket == Bucket.missing -> t("bucket.missing")
        used == 0.0 -> t("recap.free")
        n.bucket == Bucket.free -> t("recap.freeSmall", mapOf("min" to Fmt.minutes(used)))
        n.atLeast -> if (time != null) t("recap.atLeast", mapOf("min" to used.toInt(), "time" to time))
                     else t("recap.atLeastNoTime", mapOf("min" to used.toInt()))
        else -> t("recap.used", mapOf("min" to Math.round(used), "time" to (time ?: "?")))
    }
}

@Composable
private fun Timeline(night: Night, len: Double, goal: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth().height(24.dp).background(C.surface, RoundedCornerShape(6.dp))) {
            for (s in night.sessions) {
                Box(Modifier.offset(x = maxWidth * (s.offset / len).toFloat())
                    .width(maxOf(2.dp, maxWidth * (s.min / len).toFloat())).height(24.dp)
                    .background(C.moon, RoundedCornerShape(2.dp)))
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Muted(goal, 12); Muted(Dates.clock(goal, len / 2), 12); Muted("07:00", 12)
        }
    }
}

// ---------------------------------------------------------------- group

@Composable
private fun Avatar(name: String) {
    Box(Modifier.size(40.dp).background(C.surface2, CircleShape), contentAlignment = Alignment.Center) {
        Text(name.take(1).uppercase(), color = C.text1, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun GroupScreen(g: GroupModel) {
    val last = g.last
    if (last == null) {
        Page {
            Title(g.name)
            Muted(t("group.starts", mapOf("date" to longDate(g.start))))
            for (m in g.members) {
                Row(Modifier.fillMaxWidth().background(C.surface, RoundedCornerShape(16.dp)).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Avatar(m.name)
                    Text(m.name + if (m.isMe) " (${t("group.you")})" else "", color = C.text1, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f))
                    Muted(t("group.goal", mapOf("time" to m.goal)), 13)
                }
            }
            EmptyNightsCard()
        }
        return
    }
    val date = last.toString()
    val ok = g.members.count { it.nights[date]?.bucket == Bucket.free }
    val canReact = !Dates.inNightWindow(g.me.goal)
    val days = (0..6).map { last.minusDays(6L - it) }
    Page {
        Muted(t("group.lastNight") + " · " + longDate(last))
        Title(t("group.title", mapOf("ok" to ok, "n" to g.members.size)))
        Muted(t("today.groupStreak") + ": " + Fmt.nights(g.groupStreak()))
        for (m in g.members) MemberRow(g, m, date, canReact)
        Text(t(if (canReact) "group.react.hint" else "group.react.closed"), color = C.text2, fontSize = 13.sp,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Card {
            Text(t("group.week"), color = C.text1, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Spacer(Modifier.weight(1.6f))
                for (d in days) Text(dayLabel(d), color = C.text2, fontSize = 11.sp, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
            for (m in g.members) {
                Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(m.name, color = C.text1, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1.6f))
                    for (d in days) Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        Moon(m.nights[d.toString()]?.bucket ?: Bucket.future, 20.dp)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
private fun MemberRow(g: GroupModel, m: Member, date: String, canReact: Boolean) {
    val bucket = m.nights[date]?.bucket ?: Bucket.missing
    val (counts, mine) = g.reactionsFor(m, date)
    var tray by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().background(C.surface, RoundedCornerShape(16.dp)).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Avatar(m.name)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(m.name, color = C.text1, fontWeight = FontWeight.SemiBold)
                if (m.isMe) Text("  (${t("group.you")})", color = C.text2, fontSize = 13.sp)
            }
            Muted(t("bucket.${bucket.name}") + " · " + t("group.goal", mapOf("time" to m.goal)), 13)
            if (counts.isNotEmpty()) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    for ((e, c) in counts) {
                        Text(if (c > 1) "$e $c" else e, fontSize = 13.sp, color = C.text1,
                            modifier = Modifier.background(if (e == mine) C.surface2 else C.bg, RoundedCornerShape(50))
                                .then(if (e == mine) Modifier.border(1.dp, C.moon, RoundedCornerShape(50)) else Modifier)
                                .padding(horizontal = 8.dp, vertical = 2.dp))
                    }
                }
            }
        }
        if (m.isMe || !canReact) {
            Moon(bucket, 36.dp)
        } else {
            Box {
                Moon(bucket, 36.dp, Modifier.combinedClickable(
                    onClickLabel = "🌙",
                    onLongClick = { tray = true },
                    onClick = { AppState.react(m, date, "🌙") },
                ).padding(2.dp))
                DropdownMenu(expanded = tray, onDismissRequest = { tray = false }, containerColor = C.surface2) {
                    Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 4.dp)) {
                        for (e in REACTIONS) {
                            Box(Modifier.size(46.dp)
                                .background(if (e == mine) C.surface else C.surface2, CircleShape)
                                .clickable { tray = false; AppState.react(m, date, e) },
                                contentAlignment = Alignment.Center) { Text(e, fontSize = 26.sp) }
                        }
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------- history

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HistoryScreen(g: GroupModel) {
    val me = g.me
    val done = me.nights.values
    val free = done.count { it.bucket == Bucket.free }
    Page {
        Title(t("history.title"))
        Card {
            FlowRow(Modifier.fillMaxWidth(), maxItemsInEachRow = 7, horizontalArrangement = Arrangement.SpaceBetween,
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0 until g.nightsTotal) {
                    val d = g.start.plusDays(i.toLong())
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(38.dp)) {
                        Moon(me.nights[d.toString()]?.bucket ?: Bucket.future, 32.dp)
                        Text(d.dayOfMonth.toString(), color = C.text2, fontSize = 11.sp)
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Stat(t("history.free"), "$free / ${done.size}", Modifier.weight(1f))
            Stat(t("history.best"), Fmt.nights(g.bestStreak(me)), Modifier.weight(1f))
        }
        Card {
            Text(t("history.legend"), color = C.text1, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(4.dp))
            for (b in Bucket.entries) {
                Row(Modifier.padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Moon(b, 22.dp)
                    Text(if (b == Bucket.future) t("history.future") else t("bucket.${b.name}"), color = C.text1, fontSize = 14.sp)
                }
            }
        }
    }
}

// ---------------------------------------------------------------- settings

@Composable
fun SettingsScreen() {
    val context = LocalContext.current
    var usage by remember { mutableStateOf(UsageReader.hasUsageAccess(context)) }
    var battery by remember { mutableStateOf(ignoresBatteryLimits(context)) }
    var confirmLeave by remember { mutableStateOf(false) }
    var measuring by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LifecycleResumeEffect(Unit) {
        usage = UsageReader.hasUsageAccess(context)
        battery = ignoresBatteryLimits(context)
        onPauseOrDispose {}
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Title(t("settings.title"))
        Card {
            Muted(t("settings.name"), 13)
            Text(AppState.name, color = C.text1, fontSize = 17.sp)
            Muted(t("settings.name.locked"), 12)
        }
        Card {
            Muted(t("settings.goal"), 13)
            Spacer(Modifier.height(4.dp))
            TimeField(AppState.goal) { if (it != AppState.goal) AppState.updateGoal(it) }
            Muted(t("settings.goal.note"), 12)
        }
        Card {
            Muted(t("settings.and.measure"), 13)
            StatusLine(usage, t(if (usage) "settings.and.usage.ok" else "settings.and.usage.off")) { openUsageAccess(context) }
            StatusLine(battery, t(if (battery) "settings.and.battery.ok" else "settings.and.battery.off")) { requestNoBatteryLimits(context) }
            Muted(t("settings.and.last", mapOf("status" to AppState.lastStatus.ifEmpty { t("settings.and.never") })), 12)
            Spacer(Modifier.height(4.dp))
            if (measuring) CircularProgressIndicator(color = C.moon, modifier = Modifier.size(28.dp))
            else SecondaryButton(t("settings.and.now")) {
                measuring = true
                scope.launch {
                    if (!AppState.measureNow()) AppState.toast = t("settings.and.usage.off")
                    AppState.load()
                    measuring = false
                }
            }
        }
        Card {
            Muted(t("settings.language"), 13)
            Spacer(Modifier.height(6.dp))
            LanguagePicker()
        }
        AppState.group?.let { g -> Muted(t("settings.live", mapOf("group" to g.name)), 13) }
        TextButton(onClick = { confirmLeave = true }, modifier = Modifier.fillMaxWidth()) {
            Text(t("leave.button"), color = C.warn)
        }
    }
    if (confirmLeave) {
        AlertDialog(
            onDismissRequest = { confirmLeave = false },
            containerColor = C.surface,
            title = { Text(t("leave.button"), color = C.text1) },
            text = { Text(t("leave.body", mapOf("group" to (AppState.group?.name ?: ""))), color = C.text2) },
            confirmButton = { TextButton(onClick = { confirmLeave = false; AppState.leaveGroup() }) { Text(t("leave.confirm"), color = C.warn) } },
            dismissButton = { TextButton(onClick = { confirmLeave = false }) { Text(t("cancel"), color = C.moon) } },
        )
    }
}

@Composable
private fun StatusLine(ok: Boolean, text: String, fix: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(if (ok) "✓" else "⚠", color = if (ok) C.accent else C.warn, fontSize = 16.sp)
        Spacer(Modifier.width(8.dp))
        Text(text, color = if (ok) C.text1 else C.warn, fontSize = 14.sp, modifier = Modifier.weight(1f))
        if (!ok) TextButton(onClick = fix) { Text(t("settings.and.fix"), color = C.moon) }
    }
}
