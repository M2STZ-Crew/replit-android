
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
     * RepLiT Android Notification Channels
     *
     * EXISTING CHANNELS:
     * - alert_fire: Fire Volunteers and BFP alerts
     * - alert_police: Police alerts
     * - alert_medical: Medical alerts
     * - alert_barangay: Barangay alerts
     * - citizen_updates: General citizen notifications
     * - silent_ping: Vibration-only reminders
     * - updates: General notifications
     *
     * NEW CITIZEN NOTIFICATION CHANNELS:
     * - citizen_verified_v1: Incident Verified
     * - citizen_on_route_v1: Responders On Route
     * - citizen_on_scene_v1: Responders On Scene
     * - citizen_fire_out_v1: Fire Out
     *
     * Android notification channel sounds are established
     * when the channel is first created.
     */
    private fun createNotificationChannels() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager =
            getSystemService(NotificationManager::class.java) ?: return

        // Remove obsolete legacy channel.
        manager.deleteNotificationChannel("fire_alerts")

        // Audio configuration.
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Android raw audio resource URI.
        fun sound(raw: Int): Uri =
            Uri.parse(
                "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$raw"
            )

        // Existing agency alert channel configuration.
        fun alert(
            id: String,
            name: String,
            about: String,
            raw: Int
        ) = NotificationChannel(
            id,
            name,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = about

            setSound(sound(raw), attributes)

            enableVibration(true)

            vibrationPattern =
                longArrayOf(0, 600, 250, 600, 250, 600)

            enableLights(true)

            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        // New custom citizen lifecycle notification channels.
        fun citizenStage(
            id: String,
            name: String,
            raw: Int
        ) = NotificationChannel(
            id,
            name,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description =
                "Updates about a fire incident you reported."

            setSound(sound(raw), attributes)
        }

        // Existing citizen notification channel.
        val citizen = NotificationChannel(
            "citizen_updates",
            "Report updates",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description =
                "News about the reports you made and fires near you."

            setSound(sound(R.raw.sound_citizen), attributes)
        }

        // Existing silent reminder channel.
        val silent = NotificationChannel(
            "silent_ping",
            "Reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description =
                "A new fire you have not opened yet. Vibrates without a sound."

            setSound(null, null)

            enableVibration(true)

            vibrationPattern = longArrayOf(0, 400, 200, 400)

            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        // Existing general updates channel.
        val updates = NotificationChannel(
            "updates",
            "Updates",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Other news about incidents."
        }

        // Register all existing and new notification channels.
        manager.createNotificationChannels(
            listOf(

                // EXISTING: Fire Volunteers and BFP
                alert(
                    "alert_fire",
                    "Fire alerts",
                    "Fires, for Fire Volunteers and BFP, and fires near you.",
                    R.raw.sound_fire
                ),

                // EXISTING: Police
                alert(
                    "alert_police",
                    "Police alerts",
                    "Incidents that asked for the police.",
                    R.raw.sound_police
                ),

                // EXISTING: Medical
                alert(
                    "alert_medical",
                    "Medical alerts",
                    "Incidents that asked for a medical team.",
                    R.raw.sound_medical
                ),

                // EXISTING: Barangay
                alert(
                    "alert_barangay",
                    "Barangay alerts",
                    "Incidents that asked for the barangay.",
                    R.raw.sound_barangay
                ),

                // EXISTING: Citizen general updates
                citizen,

                // NEW: Incident Verified
                citizenStage(
                    "citizen_verified_v1",
                    "Incident verified",
                    R.raw.sound_verified
                ),

                // NEW: Responders On Route
                citizenStage(
                    "citizen_on_route_v1",
                    "Responders on route",
                    R.raw.sound_on_route
                ),

                // NEW: Responders On Scene
                citizenStage(
                    "citizen_on_scene_v1",
                    "Responders on scene",
                    R.raw.sound_on_scene
                ),

                // NEW: Fire Out
                citizenStage(
                    "citizen_fire_out_v1",
                    "Fire out",
                    R.raw.sound_fire_out
                ),

                // EXISTING: Silent reminders
                silent,

                // EXISTING: General notifications
                updates
            )
        )
    }
}
