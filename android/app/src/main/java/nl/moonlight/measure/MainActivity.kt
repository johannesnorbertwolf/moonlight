package nl.moonlight.measure

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.time.LocalTime
import java.time.format.DateTimeParseException

/** Test-only screen: name, goal time, permissions, and a "measure now" button. */
class MainActivity : Activity() {

    private lateinit var prefs: Prefs
    private lateinit var accessStatus: TextView
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)

        val pad = (16 * resources.displayMetrics.density).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
        }
        fun add(v: android.view.View) = column.addView(v, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = pad / 2 })
        fun label(text: String) = TextView(this).apply { this.text = text }

        add(TextView(this).apply { text = "Moonlight measurement test"; textSize = 22f })
        add(label("Your participant name (exactly as agreed in the group):"))
        val name = EditText(this).apply { setText(prefs.participant); inputType = InputType.TYPE_CLASS_TEXT }
        add(name)
        add(label("Your goal start time (HH:mm). The window always ends at 07:00:"))
        val goal = EditText(this).apply { setText(prefs.goalStart.toString()); inputType = InputType.TYPE_CLASS_DATETIME }
        add(goal)
        add(Button(this).apply {
            text = "Save"
            setOnClickListener {
                try {
                    prefs.goalStart = LocalTime.parse(goal.text.toString().trim())
                } catch (e: DateTimeParseException) {
                    goal.error = "Use HH:mm, for example 21:00"
                    return@setOnClickListener
                }
                if (name.text.isBlank()) {
                    name.error = "Enter your name"
                    return@setOnClickListener
                }
                prefs.participant = name.text.toString()
                NightlyWorker.schedule(this@MainActivity)
                Toast.makeText(this@MainActivity, "Saved. Measures every morning at about 07:05.", Toast.LENGTH_LONG).show()
            }
        })

        accessStatus = label("")
        add(accessStatus)
        add(Button(this).apply {
            text = "Open usage access settings"
            setOnClickListener { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
        })
        add(Button(this).apply {
            text = "Open battery optimization settings"
            setOnClickListener { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
        })
        add(label("In battery settings, set Moonlight test to \"Not optimized\" / \"Unrestricted\" so the morning upload isn't delayed."))

        add(Button(this).apply {
            text = "Measure last night now and upload"
            setOnClickListener { measureNow() }
        })
        status = label(prefs.lastStatus)
        add(status)

        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onResume() {
        super.onResume()
        accessStatus.text = if (UsageReader.hasUsageAccess(this)) {
            "Usage access: on ✓"
        } else {
            "Usage access: OFF. Tap the button below, find \"Moonlight test\" and allow it."
        }
        status.text = prefs.lastStatus
    }

    private fun measureNow() {
        if (prefs.participant.isBlank()) {
            Toast.makeText(this, "Save your name first", Toast.LENGTH_SHORT).show()
            return
        }
        if (!UsageReader.hasUsageAccess(this)) {
            Toast.makeText(this, "Turn on usage access first", Toast.LENGTH_SHORT).show()
            return
        }
        status.text = "Measuring…"
        Thread {
            val text = try {
                NightlyWorker.measureAndUpload(applicationContext)
            } catch (e: Exception) {
                "Failed: ${e.message}"
            }
            prefs.lastStatus = text
            runOnUiThread { status.text = text }
        }.start()
    }
}
