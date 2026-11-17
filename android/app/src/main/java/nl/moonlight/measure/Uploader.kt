package nl.moonlight.measure

import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

/** Sends a measured night to Supabase (tables from supabase/migrations/0001_measurement_test.sql). */
object Uploader {

    fun upload(participant: String, result: NightResult) {
        require(BuildConfig.SUPABASE_URL.isNotBlank() && BuildConfig.SUPABASE_KEY.isNotBlank()) {
            "Supabase URL or key missing: fill in android/local.properties and rebuild"
        }

        val events = JSONArray()
        fun event(kind: String, t: Long) = events.put(
            JSONObject()
                .put("participant", participant)
                .put("platform", "android")
                .put("kind", kind)
                .put("occurred_at", Instant.ofEpochMilli(t).toString())
                .put("source", "android_usage_events")
        )
        for (s in result.sessions) {
            event("open", s.start)
            event("close", s.end)
        }
        for (t in result.screenOffs) event("screen_off", t)

        if (events.length() > 0) {
            post(
                "test_events?on_conflict=participant,platform,kind,occurred_at",
                events.toString(),
                "resolution=ignore-duplicates,return=minimal",
            )
        }

        val night = JSONObject()
            .put("participant", participant)
            .put("night_date", result.window.nightDate.toString())
            .put("window_start", result.window.start.toInstant().toString())
            .put("window_end", result.window.end.toInstant().toString())
            .put("precise_seconds", result.preciseSeconds)
            .put("crossed_at", result.crossedAt?.let { Instant.ofEpochMilli(it).toString() } ?: JSONObject.NULL)
            .put("opens", result.opens)
            .put("computed_at", Instant.now().toString())
        post(
            "test_android_nights?on_conflict=participant,night_date",
            JSONArray().put(night).toString(),
            "resolution=merge-duplicates,return=minimal",
        )
    }

    private fun post(path: String, body: String, prefer: String) {
        val url = URL(BuildConfig.SUPABASE_URL.trimEnd('/') + "/rest/v1/" + path)
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = 15_000
            conn.readTimeout = 30_000
            conn.doOutput = true
            conn.setRequestProperty("apikey", BuildConfig.SUPABASE_KEY)
            conn.setRequestProperty("Authorization", "Bearer " + BuildConfig.SUPABASE_KEY)
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Prefer", prefer)
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                throw IOException("Upload to $path failed: HTTP $code $err")
            }
        } finally {
            conn.disconnect()
        }
    }
}
