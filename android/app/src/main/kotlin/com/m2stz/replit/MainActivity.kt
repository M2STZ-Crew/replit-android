
package com.m2stz.replit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.google.firebase.appdistribution.FirebaseAppDistribution
import com.google.firebase.appdistribution.FirebaseAppDistributionException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** lib/updates/app_updates.dart's channel, kept for its progress calls. */
    private var updates: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // lib/security/developer_mode.dart: whether Developer options are on,
        // and the way to them in Settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "replit/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "developerOptions" -> result.success(developerOptionsOn())
                    "openDeveloperOptions" -> result.success(openDeveloperOptions())
                    else -> result.notImplemented()
                }
            }
        // lib/updates/app_updates.dart: "Check for updates" through Firebase App
        // Distribution, where CI sends every Android build.
        updates = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "replit/updates")
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "check" -> checkForUpdate(result)
                        "install" -> installUpdate(result)
                        else -> result.notImplemented()
                    }
                }
            }
    }

    /** App Distribution, or null in a build with no Firebase config to start it
     *  (google-services.json is not in the repository). */
    private fun appDistribution(): FirebaseAppDistribution? =
        try {
            FirebaseAppDistribution.getInstance()
        } catch (e: IllegalStateException) {
            null
        }

    private fun fail(result: MethodChannel.Result, e: Exception) {
        val code = (e as? FirebaseAppDistributionException)?.errorCode?.name ?: "UNKNOWN"
        result.error(code, e.message, null)
    }

    /** A newer release for this tester as a map, or null when this is the
     *  newest. Signs the tester in first; App Distribution remembers it. */
    private fun checkForUpdate(result: MethodChannel.Result) {
        val distribution = appDistribution()
            ?: return result.error("UNAVAILABLE", "Firebase is not set up in this build.", null)
        fun check() {
            distribution.checkForNewRelease()
                .addOnSuccessListener { release ->
                    result.success(
                        release?.let {
                            mapOf(
                                "version" to it.displayVersion,
                                "build" to it.versionCode,
                                "notes" to it.releaseNotes
                            )
                        }
                    )
                }
                .addOnFailureListener { e -> fail(result, e) }
        }
        if (distribution.isTesterSignedIn) {
            check()
        } else {
            distribution.signInTester()
                .addOnSuccessListener { check() }
                .addOnFailureListener { e -> fail(result, e) }
        }
    }

    /** Download the release the last check found and hand it to Android's
     *  installer, reporting progress to Dart as it downloads. */
    private fun installUpdate(result: MethodChannel.Result) {
        val distribution = appDistribution()
            ?: return result.error("UNAVAILABLE", "Firebase is not set up in this build.", null)
        var answered = false
        distribution.updateApp()
            .addOnProgressListener { progress ->
                updates?.invokeMethod(
                    "progress",
                    mapOf(
                        "downloaded" to progress.apkBytesDownloaded,
                        "total" to progress.apkFileTotalBytes,
                        "status" to progress.updateStatus.name
                    )
                )
            }
            .addOnSuccessListener {
                if (!answered) {
                    answered = true
                    result.success(true)
                }
            }
            .addOnFailureListener { e ->
                if (!answered) {
                    answered = true
                    fail(result, e)
                }
            }
    }

    /** The "Developer options" switch at the top of that Settings page. */
    private fun developerOptionsOn(): Boolean =
        Settings.Global.getInt(
            contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0
        ) != 0

    /** Developer options in Settings; Settings itself where a phone has no
     *  direct way in. False when neither opens. */
    private fun openDeveloperOptions(): Boolean {
        for (action in listOf(
            Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS,
            Settings.ACTION_SETTINGS
        )) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Try the next way in.
            }
        }
        return false
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
     *
     * v1.12.23: a channel made before this version holds its recording by
     * resource number, and adding, removing or renaming a file in res/raw
     * renumbers every file after it alphabetically. Adding the four stage
     * recordings did exactly that: on a phone that had the app before them,
     * "alert_medical" now plays sound_fire_out and "alert_police" plays
     * sound_medical (aapt2 dump of v1.12.17 against v1.12.22). Channels made
     * from now on name their file instead, which no renumbering moves. Leave
     * res/raw's list alone unless the channels it would move get new ids
     * (test/sound_files_test.dart holds the list).
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

        // Android raw audio resource URI, by name:
        // android.resource://com.m2stz.replit/raw/sound_fire.
        fun sound(raw: Int): Uri =
            Uri.parse(
                "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/" +
                    "raw/${resources.getResourceEntryName(raw)}"
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
