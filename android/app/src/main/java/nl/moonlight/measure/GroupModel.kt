// Rules from CONCEPT.md §3 and the group as the screens see it. Port of ios/Moonlight/Model.swift
// (and web/data.js, web/estimate.js); keep them in sync.
package nl.moonlight.measure

import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

enum class Bucket {
    free, light, medium, heavy, very_heavy, missing, future;

    companion object {
        fun from(minutes: Double): Bucket = when {
            minutes < 2 -> free
            minutes < 5 -> light
            minutes < 15 -> medium
            minutes < 60 -> heavy
            else -> very_heavy
        }
    }
}

/** A stretch of use; [offset] is minutes after the window start. */
data class UseSpan(val offset: Double, val min: Double)

data class Night(
    val date: String,
    val bucket: Bucket,
    val min: Double?,            // estimated minutes (null when missing)
    val atLeast: Boolean,        // iPhone Screen Time nights only know "at least N minutes"
    val sessions: List<UseSpan>,
    val crossedAt: Instant?,
)

data class Member(
    val id: String,
    val name: String,
    val goal: String,
    val platform: String,
    val isMe: Boolean,
    val nights: Map<String, Night>,
)

data class Reaction(val target: String, val night: String, val from: String, val emoji: String)

val REACTIONS = listOf("🌙", "👏", "🔥", "😴", "❤️", "🛌", "🦉", "🦥", "🥱")

object Dates {
    val zone: ZoneId get() = ZoneId.systemDefault()

    fun minutes(hhmm: String): Int = LocalTime.parse(hhmm).let { it.hour * 60 + it.minute }

    /** Date of the most recent completed night (dated by the evening it starts). */
    fun lastNightDate(now: ZonedDateTime = ZonedDateTime.now()): LocalDate =
        now.toLocalDate().minusDays(if (!now.toLocalTime().isBefore(WINDOW_END)) 1 else 2)

    fun inNightWindow(goal: String, now: ZonedDateTime = ZonedDateTime.now()): Boolean {
        val m = now.hour * 60 + now.minute
        val s = minutes(goal)
        val e = WINDOW_END.hour * 60 + WINDOW_END.minute
        return if (s > e) m >= s || m < e else m in s until e
    }

    fun minutesUntilWindow(goal: String, now: ZonedDateTime = ZonedDateTime.now()): Int {
        if (inNightWindow(goal, now)) return 0
        var d = minutes(goal) - (now.hour * 60 + now.minute)
        if (d < 0) d += 24 * 60
        return d
    }

    fun windowLength(goal: String): Int {
        var d = WINDOW_END.hour * 60 + WINDOW_END.minute - minutes(goal)
        if (d <= 0) d += 24 * 60
        return d
    }

    fun clock(goal: String, offset: Double): String {
        val m = (minutes(goal) + Math.round(offset).toInt()) % (24 * 60)
        return "%02d:%02d".format(m / 60, m % 60)
    }

    fun parseInstant(s: String): Instant? =
        runCatching { OffsetDateTime.parse(s).toInstant() }.getOrNull()
            ?: runCatching { Instant.parse(s) }.getOrNull()
            ?: runCatching { OffsetDateTime.parse(s.replace(" ", "T")).toInstant() }.getOrNull()
}

/** Turns open/close events into use intervals and nights (same rule as web/estimate.js). */
object Estimate {
    private const val CAP_MS = 10 * 60 * 1000L
    private const val ORPHAN_MS = 60 * 1000L
    private const val MARGIN_MS = 2 * 60 * 1000L

    data class Event(val kind: String, val at: Instant)

    fun useIntervals(events: List<Event>): List<Pair<Instant, Instant>> {
        val out = mutableListOf<Pair<Instant, Instant>>()
        var depth = 0
        var since: Instant? = null
        var prev: Instant? = null
        fun stop(t: Instant) {
            val s = since
            if (s != null && t.isAfter(s)) out += s to t
            since = null
        }
        for (e in events) {
            val p = prev
            if (depth > 0 && since != null && p != null && e.at.toEpochMilli() - p.toEpochMilli() > CAP_MS) {
                stop(p.plusMillis(CAP_MS))
                depth = 0
            }
            if (e.kind == "open") {
                if (depth == 0) since = e.at
                depth++
            } else if (e.kind == "close") {
                if (depth == 0) out += e.at.minusMillis(ORPHAN_MS) to e.at
                else {
                    depth--
                    if (depth == 0) stop(e.at)
                }
            }
            prev = e.at
        }
        val p = prev
        if (depth > 0 && since != null && p != null) stop(p.plusMillis(CAP_MS))
        return out
    }

    fun summarize(intervals: List<Pair<Instant, Instant>>, date: LocalDate, goal: String): Night {
        val w = NightWindow.forNight(date, LocalTime.parse(goal), Dates.zone)
        val ws = w.start.toInstant()
        val we = w.end.toInstant()
        var totalMs = 0L
        var crossed: Instant? = null
        val sessions = mutableListOf<UseSpan>()
        for ((a, b) in intervals.sortedBy { it.first }) {
            val a2 = if (a.isAfter(ws)) a else ws
            val b2 = if (b.isBefore(we)) b else we
            if (!b2.isAfter(a2)) continue
            val len = b2.toEpochMilli() - a2.toEpochMilli()
            if (crossed == null && totalMs + len >= MARGIN_MS) crossed = a2.plusMillis(MARGIN_MS - totalMs)
            totalMs += len
            sessions += UseSpan(ChronoUnit.SECONDS.between(ws, a2) / 60.0, Math.round(len / 6000.0) / 10.0)
        }
        val min = Math.round(totalMs / 6000.0) / 10.0
        return Night(date.toString(), Bucket.from(min), min, false, sessions, crossed)
    }
}

data class GroupModel(
    val live: Boolean,
    val name: String,
    val code: String?,
    val start: LocalDate,
    val last: LocalDate?,          // most recent finished night, null before the first one
    val nightsTotal: Int,
    val members: List<Member>,
    val reactions: List<Reaction>,
    val meId: String,
) {
    val me: Member get() = members.first { it.isMe }

    fun personalStreak(m: Member): Int {
        var d = last ?: return 0
        var n = 0
        while (true) {
            val night = m.nights[d.toString()] ?: break
            if (night.bucket != Bucket.missing) {
                if (night.bucket != Bucket.free) break
                n++
            }
            d = d.minusDays(1)
        }
        return n
    }

    fun groupStreak(): Int {
        var d = last ?: return 0
        var n = 0
        while (!d.isBefore(start)) {
            val reported = members.mapNotNull { it.nights[d.toString()] }.filter { it.bucket != Bucket.missing }
            if (reported.isNotEmpty()) {
                if (!reported.all { it.bucket == Bucket.free }) break
                n++
            }
            d = d.minusDays(1)
        }
        return n
    }

    fun bestStreak(m: Member): Int {
        var best = 0
        var run = 0
        for (key in m.nights.keys.sorted()) {
            val b = m.nights.getValue(key).bucket
            if (b == Bucket.missing) continue
            run = if (b == Bucket.free) run + 1 else 0
            best = maxOf(best, run)
        }
        return best
    }

    /** Reaction counts in [REACTIONS] order, and my own reaction. */
    fun reactionsFor(member: Member, night: String): Pair<List<Pair<String, Int>>, String?> {
        val counts = mutableMapOf<String, Int>()
        var mine: String? = null
        for (r in reactions) {
            if (r.target != member.id || r.night != night) continue
            counts[r.emoji] = (counts[r.emoji] ?: 0) + 1
            if (r.from == meId) mine = r.emoji
        }
        return REACTIONS.mapNotNull { e -> counts[e]?.let { e to it } } to mine
    }

    companion object {
        fun from(d: JSONObject, now: ZonedDateTime = ZonedDateTime.now()): GroupModel {
            val g = d.getJSONObject("group")
            val start = LocalDate.parse(g.getString("challenge_start"))
            val total = g.getInt("challenge_nights")
            val end = start.plusDays(total - 1L)
            val last: LocalDate? = Dates.lastNightDate(now)
                .let { if (it.isAfter(end)) end else it }
                .takeIf { !it.isBefore(start) }

            val eventsBy = mutableMapOf<String, MutableList<Estimate.Event>>()
            d.optJSONArray("events")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val e = arr.getJSONArray(i)
                    val at = Dates.parseInstant(e.getString(2)) ?: continue
                    eventsBy.getOrPut(e.getString(0)) { mutableListOf() } += Estimate.Event(e.getString(1), at)
                }
            }
            val android = mutableSetOf<String>()
            d.optJSONArray("android_nights")?.let { arr ->
                for (i in 0 until arr.length()) arr.getJSONObject(i).let { android += it.getString("participant") + "|" + it.getString("night") }
            }
            val screenTime = mutableMapOf<String, JSONObject>()
            val usesApp = mutableSetOf<String>()
            d.optJSONArray("screen_time_nights")?.let { arr ->
                for (i in 0 until arr.length()) arr.getJSONObject(i).let {
                    screenTime[it.getString("participant") + "|" + it.getString("night")] = it
                    usesApp += it.getString("participant")
                }
            }
            val meId = d.getString("me")
            val membersArr = d.getJSONArray("members")
            val members = (0 until membersArr.length()).map { i ->
                val p = membersArr.getJSONObject(i)
                val name = p.getString("name")
                val goal = p.getString("goal")
                val platform = p.getString("platform")
                val intervals = Estimate.useIntervals(eventsBy[name].orEmpty())
                val nights = mutableMapOf<String, Night>()
                if (last != null) {
                    var day = start
                    while (!day.isAfter(last)) {
                        val key = day.toString()
                        nights[key] = when {
                            name in usesApp -> screenTime["$name|$key"]?.let { s ->
                                val m = s.getInt("minutes").toDouble()
                                Night(key, Bucket.from(m), m, true, emptyList(),
                                    if (s.isNull("crossed_at")) null else Dates.parseInstant(s.getString("crossed_at")))
                            } ?: Night(key, Bucket.missing, null, false, emptyList(), null)
                            platform == "android" && "$name|$key" !in android ->
                                Night(key, Bucket.missing, null, false, emptyList(), null)
                            else -> Estimate.summarize(intervals, day, goal)
                        }
                        day = day.plusDays(1)
                    }
                }
                Member(p.getString("id"), name, goal, platform, p.getString("id") == meId, nights)
            }
            val rArr = d.optJSONArray("reactions")
            val reactions = if (rArr == null) emptyList() else (0 until rArr.length()).map { i ->
                rArr.getJSONObject(i).let { Reaction(it.getString("target"), it.getString("night"), it.getString("from"), it.getString("emoji")) }
            }
            return GroupModel(true, g.getString("name"), g.optString("code").ifEmpty { null }, start, last, total,
                members, reactions, meId)
        }
    }
}
