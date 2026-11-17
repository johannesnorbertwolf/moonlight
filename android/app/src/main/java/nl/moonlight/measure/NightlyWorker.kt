package nl.moonlight.measure

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.time.Duration
import java.time.LocalTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

/**
 * Runs once a day shortly after the window ends. It (re)measures the last two completed nights,
 * so a missed or late run catches up; the server ignores duplicates.
 */
class NightlyWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val prefs = Prefs(ctx)
        if (prefs.participant.isBlank() || !UsageReader.hasUsageAccess(ctx)) return Result.success()
        return try {
            prefs.lastStatus = measureAndUpload(ctx)
            Result.success()
        } catch (e: Exception) {
            prefs.lastStatus = "Upload failed at ${ZonedDateTime.now().format(TIME)}: ${e.message}"
            if (runAttemptCount < 5) Result.retry() else Result.failure()
        }
    }

    companion object {
        private const val NAME = "moonlight-nightly"
        private val RUN_AT: LocalTime = LocalTime.of(7, 5)
        private val TIME: DateTimeFormatter = DateTimeFormatter.ofPattern("EEE HH:mm")

        fun schedule(context: Context) {
            val now = ZonedDateTime.now()
            var next = now.with(RUN_AT)
            if (!next.isAfter(now)) next = next.plusDays(1)
            val delay = Duration.between(now, next).toMinutes()

            val request = PeriodicWorkRequestBuilder<NightlyWorker>(24, TimeUnit.HOURS)
                .setInitialDelay(delay, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.CANCEL_AND_REENQUEUE, request)
        }

        /** Measures and uploads the last two completed nights; returns a status line for the UI. */
        fun measureAndUpload(context: Context): String {
            val prefs = Prefs(context)
            val now = ZonedDateTime.now()
            val last = NightWindow.lastCompleted(now, prefs.goalStart)
            val previous = NightWindow.forNight(last.nightDate.minusDays(1), prefs.goalStart, now.zone)
            for (w in listOf(previous, last)) {
                Uploader.upload(prefs.participant, UsageReader.read(context, w))
            }
            val r = UsageReader.read(context, last)
            val minutes = r.preciseSeconds / 60
            val seconds = r.preciseSeconds % 60
            val crossed = r.crossedAt?.let {
                java.time.Instant.ofEpochMilli(it).atZone(now.zone).format(DateTimeFormatter.ofPattern("HH:mm"))
            }
            return buildString {
                append("Night of ${last.nightDate} (${last.start.format(DateTimeFormatter.ofPattern("HH:mm"))}–07:00): ")
                append("${minutes}m ${seconds}s in ${r.opens} session(s)")
                if (crossed != null) append(", 2-min margin crossed at $crossed")
                append(".\nUploaded ${now.format(TIME)}.")
            }
        }
    }
}
