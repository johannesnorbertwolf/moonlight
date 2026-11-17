package nl.moonlight.measure

import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/** Window end is fixed for everyone (CONCEPT.md §3). */
val WINDOW_END: LocalTime = LocalTime.of(7, 0)

/**
 * One night window. A night belongs to the date it starts on (evening convention), so
 * [nightDate] is the evening date even when the goal start is after midnight.
 */
data class NightWindow(
    val nightDate: LocalDate,
    val start: ZonedDateTime,
    val end: ZonedDateTime,
) {
    companion object {
        fun forNight(nightDate: LocalDate, goalStart: LocalTime, zone: ZoneId): NightWindow {
            // Goal times before noon (e.g. 00:30) fall on the morning after the night date.
            val startDate = if (goalStart.isBefore(LocalTime.NOON)) nightDate.plusDays(1) else nightDate
            val start = ZonedDateTime.of(startDate, goalStart, zone)
            val end = ZonedDateTime.of(nightDate.plusDays(1), WINDOW_END, zone)
            return NightWindow(nightDate, start, end)
        }

        /** The most recent night whose window has fully ended at [now]. */
        fun lastCompleted(now: ZonedDateTime, goalStart: LocalTime): NightWindow {
            val today = now.toLocalDate()
            val nightDate = if (!now.toLocalTime().isBefore(WINDOW_END)) today.minusDays(1) else today.minusDays(2)
            return forNight(nightDate, goalStart, now.zone)
        }
    }
}
