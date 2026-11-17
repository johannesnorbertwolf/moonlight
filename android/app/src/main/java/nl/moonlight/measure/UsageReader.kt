package nl.moonlight.measure

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process

/** A stretch of time with some app in the foreground (app switches merged). */
data class Session(val start: Long, val end: Long)

data class NightResult(
    val window: NightWindow,
    /** Sessions overlapping the extended query range; uploaded as open/close events. */
    val sessions: List<Session>,
    /** Times the screen turned off or the lock screen appeared. */
    val screenOffs: List<Long>,
    /** Precise foreground time inside the window, in seconds. */
    val preciseSeconds: Long,
    /** When precise use inside the window reached the 2-minute margin, or null. */
    val crossedAt: Long?,
    /** Number of sessions that overlap the window. */
    val opens: Int,
)

object UsageReader {
    /** Look this far before the window so a session that started earlier is still seen. */
    private const val LOOKBACK_MS = 3 * 60 * 60 * 1000L
    /** Gaps shorter than this between foreground periods count as one session. */
    private const val MERGE_GAP_MS = 2_000L
    const val MARGIN_SECONDS = 120L

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun excludedPackages(context: Context): Set<String> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launchers = context.packageManager
            .queryIntentActivities(home, PackageManager.MATCH_ALL)
            .map { it.activityInfo.packageName }
        return (launchers + "com.android.systemui").toSet()
    }

    fun read(context: Context, window: NightWindow, now: Long = System.currentTimeMillis()): NightResult {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val windowStart = window.start.toInstant().toEpochMilli()
        val windowEnd = window.end.toInstant().toEpochMilli()
        val queryStart = windowStart - LOOKBACK_MS
        val queryEnd = minOf(windowEnd, now)
        val excluded = excludedPackages(context)

        val raw = mutableListOf<Session>()
        val screenOffs = mutableListOf<Long>()
        var current: String? = null
        var currentStart = 0L

        fun closeCurrent(t: Long) {
            if (current != null && t > currentStart) raw += Session(currentStart, t)
            current = null
        }

        val events = usm.queryEvents(queryStart, queryEnd)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val t = e.timeStamp
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    val pkg = e.packageName
                    if (pkg in excluded) {
                        closeCurrent(t)
                    } else if (pkg != current) {
                        closeCurrent(t)
                        current = pkg
                        currentStart = t
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (e.packageName == current) closeCurrent(t)
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN -> {
                    screenOffs += t
                    closeCurrent(t)
                }
            }
        }
        closeCurrent(queryEnd)

        val sessions = merge(raw)
        return summarize(window, sessions, screenOffs)
    }

    internal fun merge(raw: List<Session>): List<Session> {
        val sorted = raw.sortedBy { it.start }
        val out = mutableListOf<Session>()
        for (s in sorted) {
            val last = out.lastOrNull()
            if (last != null && s.start - last.end <= MERGE_GAP_MS) {
                out[out.size - 1] = Session(last.start, maxOf(last.end, s.end))
            } else {
                out += s
            }
        }
        return out
    }

    internal fun summarize(window: NightWindow, sessions: List<Session>, screenOffs: List<Long>): NightResult {
        val ws = window.start.toInstant().toEpochMilli()
        val we = window.end.toInstant().toEpochMilli()
        var totalMs = 0L
        var crossedAt: Long? = null
        var opens = 0
        for (s in sessions) {
            val a = maxOf(s.start, ws)
            val b = minOf(s.end, we)
            if (b <= a) continue
            opens++
            val before = totalMs
            totalMs += b - a
            if (crossedAt == null && totalMs >= MARGIN_SECONDS * 1000) {
                crossedAt = a + (MARGIN_SECONDS * 1000 - before)
            }
        }
        return NightResult(window, sessions, screenOffs, totalMs / 1000, crossedAt, opens)
    }
}
