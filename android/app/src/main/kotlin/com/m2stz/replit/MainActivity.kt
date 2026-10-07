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
     * The two channels the server sends to (app/integrations/fcm.py):
     *
     *  - "fire_alerts": a push that says there is a fire — a new incident for
     *    staff, a neighbour's first alert, an alarm escalation. Rings with the
     *    app's fire alarm (res/raw/fire_alarm.wav), shows on the lock screen.
     *  - "updates": everything else, with the phone's own tone.
     *
     * They must exist before a push arrives with the app closed, so they are made
     * every time the app opens (creating an existing channel changes nothing).
     * Android fixes a channel's sound once it is made: a new sound needs a new
     * channel id, not an edit here. People can still change either channel in
     * the phone's settings.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val alarm = Uri.parse(
            "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/${R.raw.fire_alarm}"
        )
        val fire = NotificationChannel(
            "fire_alerts",
            "Fire alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "A fire reported near you or to your team. Rings with the fire alarm."
            setSound(
                alarm,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
            enableLights(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val updates = NotificationChannel(
            "updates",
            "Updates",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "News about your reports and incidents."
        }
        manager.createNotificationChannels(listOf(fire, updates))
    }
}
