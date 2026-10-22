package com.m2stz.replit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * The channels the server sends to (app/integrations/fcm.py), one per
     * sound — the recordings chosen for the pilot, in res/raw:
     *
     *  - "alert_fire", "alert_police", "alert_medical", "alert_barangay":
     *    a new incident for staff (each hears their own agency's), a
     *    neighbour's first alert (fire), an alarm escalation (fire), and a
     *    coordinator's reminder. Shows on the lock screen.
     *  - "citizen_updates": a resident's other news, with the citizen sound.
     *  - "silent_ping": a coordinator's reminder that only vibrates.
     *  - "updates": anything else, with the phone's own tone.
     *
     * They must exist before a push arrives with the app closed, so they are made
     * every time the app opens (creating an existing channel changes nothing).
     * Android fixes a channel's sound once it is made: a new sound needs a new
     * channel id, not an edit here. People can still change any channel in the
     * phone's settings. v1.12.6's "fire_alerts" (a synthesized alarm) is gone.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.deleteNotificationChannel("fire_alerts")

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        fun sound(raw: Int): Uri =
            Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$raw")

        fun alert(id: String, name: String, about: String, raw: Int) =
            NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = about
                setSound(sound(raw), attributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

        val citizen = NotificationChannel(
            "citizen_updates",
            "Report updates",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "News about the reports you made and fires near you."
            setSound(sound(R.raw.sound_citizen), attributes)
        }
        val silent = NotificationChannel(
            "silent_ping",
            "Reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "A new fire you have not opened yet. Vibrates without a sound."
            setSound(null, null)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val updates = NotificationChannel(
            "updates",
            "Updates",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Other news about incidents."
        }
        manager.createNotificationChannels(
            listOf(
                alert(
                    "alert_fire",
                    "Fire alerts",
                    "Fires, for Fire Volunteers and BFP, and fires near you.",
                    R.raw.sound_fire,
                ),
                alert(
                    "alert_police",
                    "Police alerts",
                    "Incidents that asked for the police.",
                    R.raw.sound_police,
                ),
                alert(
                    "alert_medical",
                    "Medical alerts",
                    "Incidents that asked for a medical team.",
                    R.raw.sound_medical,
                ),
                alert(
                    "alert_barangay",
                    "Barangay alerts",
                    "Incidents that asked for the barangay.",
                    R.raw.sound_barangay,
                ),
                citizen,
                silent,
                updates,
            ),
        )
    }
}
