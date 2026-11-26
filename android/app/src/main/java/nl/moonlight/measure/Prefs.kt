package nl.moonlight.measure

import android.content.Context
import java.time.LocalTime

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("moonlight", Context.MODE_PRIVATE)

    /** My participant id in the group; measurements are uploaded under it (migration 0005). */
    var participant: String
        get() = sp.getString("participant", "") ?: ""
        set(v) = sp.edit().putString("participant", v.trim()).apply()

    /** My name in the group. */
    var name: String
        get() = sp.getString("display_name", "") ?: ""
        set(v) = sp.edit().putString("display_name", v.trim()).apply()

    var onboarded: Boolean
        get() = sp.getBoolean("onboarded", false)
        set(v) = sp.edit().putBoolean("onboarded", v).apply()

    var goalStart: LocalTime
        get() = LocalTime.parse(sp.getString("goal_start", "21:00"))
        set(v) = sp.edit().putString("goal_start", v.toString()).apply()

    /** "en" or "nl"; empty = follow the phone. */
    var lang: String
        get() = sp.getString("lang", "") ?: ""
        set(v) = sp.edit().putString("lang", v).apply()

    /** Time (epoch ms) of the newest event already uploaded; older events are never sent again. */
    var uploadedUntil: Long
        get() = sp.getLong("uploaded_until", 0L)
        set(v) = sp.edit().putLong("uploaded_until", v).apply()

    /** Result of the last measurement, shown in Settings. */
    var lastStatus: String
        get() = sp.getString("last_status", "") ?: ""
        set(v) = sp.edit().putString("last_status", v).apply()

    // Supabase anonymous session.
    var accessToken: String
        get() = sp.getString("access_token", "") ?: ""
        set(v) = sp.edit().putString("access_token", v).apply()
    var refreshToken: String
        get() = sp.getString("refresh_token", "") ?: ""
        set(v) = sp.edit().putString("refresh_token", v).apply()
    var tokenExpiresAt: Long
        get() = sp.getLong("token_expires_at", 0L)
        set(v) = sp.edit().putLong("token_expires_at", v).apply()

    fun clearGroup() {
        sp.edit()
            .remove("participant").remove("onboarded").remove("uploaded_until").remove("last_status")
            .remove("access_token").remove("refresh_token").remove("token_expires_at")
            .apply()
    }
}
