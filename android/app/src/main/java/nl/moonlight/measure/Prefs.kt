package nl.moonlight.measure

import android.content.Context
import java.time.LocalTime

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("moonlight", Context.MODE_PRIVATE)

    var participant: String
        get() = sp.getString("participant", "") ?: ""
        set(v) = sp.edit().putString("participant", v.trim()).apply()

    var goalStart: LocalTime
        get() = LocalTime.parse(sp.getString("goal_start", "21:00"))
        set(v) = sp.edit().putString("goal_start", v.toString()).apply()

    /** Time (epoch ms) of the newest event already uploaded; older events are never sent again. */
    var uploadedUntil: Long
        get() = sp.getLong("uploaded_until", 0L)
        set(v) = sp.edit().putLong("uploaded_until", v).apply()

    var lastStatus: String
        get() = sp.getString("last_status", "No night measured yet.") ?: ""
        set(v) = sp.edit().putString("last_status", v).apply()
}
