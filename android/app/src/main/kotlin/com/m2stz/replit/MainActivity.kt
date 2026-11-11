
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
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ would slide the app's first frame up under its
            // fading launch screen. That frame is the app's splash, with the
            // same mark in the same place on the same ground
            // (lib/screens/splash_screen.dart), so the launch screen just goes.
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // lib/security/developer_mode.dart: whether Developer options and USB
        // debugging are on, and Exit on the warning.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "replit/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceSettings" -> result.success(
                        mapOf(
                            "developerOptions" to developerOptionsOn(),
                            "usbDebugging" to usbDebuggingOn()
                        )
                    )
                    "exit" -> {
                        result.success(null)
                        finishAndRemoveTask()
                    }
                    // lib/theme_choice.dart: the app's ground is its own switch,
                    // but Android draws the launch screen before the app runs,
                    // in the phone's light or dark. From Android 13 it keeps a
                    // launch screen theme for the app, used from the next
                    // launch on, so the launch screen has the app's ground and
                    // the hand-off to the splash doesn't flash.
                    "launchGround" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val light = call.argument<Boolean>("light") == true
                            splashScreen.setSplashScreenTheme(
                                if (light) R.style.SplashOnLight else R.style.SplashOnDark
                            )
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    // lib/widgets/email_link_sheet.dart: Open Gmail, once
                    // the link that confirms a resident's email has gone out.
                    "openMailApp" -> result.success(
                        openMailApp(gmailFirst = call.argument<Boolean>("gmail") == true)
                    )
                    // lib/alerts/buzz.dart: every alert vibrates with the
                    // app open too, in the alert channels' rhythm (v1.12.35).
                    "vibrate" -> result.success(
                        vibrate(call.argument<List<Number>>("pattern"))
                    )
                    else -> result.notImplemented()
                }
            }
        // lib/updates/app_updates.dart: "Check for updates". Dart downloads the
        // newest APK from the repository's GitHub releases into cache/updates;
        // this checks it against the release's SHA-256 and hands it to
        // Android's installer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "replit/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updatesDir" -> result.success(updatesDir().absolutePath)
                    "install" -> installUpdate(
                        call.argument<String>("path"),
                        call.argument<String>("sha256"),
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /** Vibrate once through [pattern] (off, on, off, on … in milliseconds).
     *  False when the phone has no vibrator. */
    private fun vibrate(pattern: List<Number>?): Boolean {
        val timings = (pattern ?: listOf(0, 600, 250, 600, 250, 600))
            .map { it.toLong() }
            .toLongArray()
        val vibrator: Vibrator? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as? Vibrator
            }
        if (vibrator == null || !vibrator.hasVibrator()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
        return true
    }

    /** Where a downloaded update waits: cache/updates, the one folder the
     *  updates FileProvider shares (res/xml/update_paths.xml). */
    private fun updatesDir(): File = File(cacheDir, "updates").apply { mkdirs() }

    /** Check the downloaded APK against the release's SHA-256, off the main
     *  thread, then open Android's installer on it. The first time, Android
     *  also asks to allow installs from RepLiT, then carries on. */
    private fun installUpdate(path: String?, sha256: String?, result: MethodChannel.Result) {
        val dir = updatesDir().canonicalFile
        val apk = path?.let { File(it).canonicalFile }
        if (apk == null || apk.parentFile != dir || !apk.isFile || sha256.isNullOrBlank()) {
            return result.error("DOWNLOAD_FAILURE", "No downloaded update to install.", null)
        }
        Thread {
            val matches = try {
                sha256.equals(sha256Of(apk), ignoreCase = true)
            } catch (e: IOException) {
                false
            }
            runOnUiThread {
                if (!matches) {
                    apk.delete()
                    result.error("CORRUPT", "The download does not match the release.", null)
                    return@runOnUiThread
                }
                try {
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                            )
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALLATION_FAILURE", e.message, null)
                }
            }
        }.start()
    }

    private fun sha256Of(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1 shl 16)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    /** The "Developer options" switch at the top of that Settings page. */
    /**
     * Opens Gmail, or the phone's email app, at the inbox: Gmail first for a
     * Gmail address, each falling back to the other. False when neither
     * opens. Starting an activity needs no <queries> entry on Android 11+.
     */
    private fun openMailApp(gmailFirst: Boolean): Boolean {
        val gmail = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage("com.google.android.gm")
        val mail = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_EMAIL)
        for (intent in if (gmailFirst) listOf(gmail, mail) else listOf(mail, gmail)) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Not on this phone: the other one.
            } catch (e: SecurityException) {
                // Not ours to open: the other one.
            }
        }
        return false
    }

    private fun developerOptionsOn(): Boolean =
        Settings.Global.getInt(
            contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0
        ) != 0

    /** "USB debugging", inside Developer options. */
    private fun usbDebuggingOn(): Boolean =
        Settings.Global.getInt(
            contentResolver,
            Settings.Global.ADB_ENABLED,
            0
        ) != 0

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
     * - citizen_verified_v2: Incident Verified
     * - citizen_on_route_v1: Responders On Route
     * - citizen_on_scene_v1: Responders On Scene
     * - citizen_fire_out_v1: Fire Out
     * - citizen_rejected_v1: Report Rejected
     *
     * v1.12.33 (9 November): sound_rejected is new, and it sorts before
     * sound_verified, so on a phone whose channels predate v1.12.23 (made by
     * resource number, below) "citizen_verified_v1" would play the rejected
     * recording. Verified moved to "citizen_verified_v2", made by name, and
     * the old channel is deleted. The server names the same ids
     * (app/integrations/fcm.py SOUND_CHANNELS in replit-backend).
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

        // Remove obsolete legacy channels. citizen_verified_v1 may hold
        // sound_verified by number, which sound_rejected moved (v1.12.33).
        manager.deleteNotificationChannel("fire_alerts")
        manager.deleteNotificationChannel("citizen_verified_v1")

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

            enableVibration(true)

            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
        }

        // Citizen general updates. Before v1.12.35 "citizen_updates", which
        // did not vibrate; a channel's settings are fixed once made, so the
        // vibrating one is new ("vibration when notifying ... every notif").
        fun citizenChannel(id: String) = NotificationChannel(
            id,
            "Report updates",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description =
                "News about the reports you made and fires near you."

            setSound(sound(R.raw.sound_citizen), attributes)

            enableVibration(true)

            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
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

        // General updates; "updates_v2" vibrates (v1.12.35).
        fun updatesChannel(id: String) = NotificationChannel(
            id,
            "Updates",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Other news about incidents."

            enableVibration(true)

            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
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

                // Citizen general updates: the vibrating one, and the old one
                // for a server that still names it.
                citizenChannel("citizen_updates_v2"),
                citizenChannel("citizen_updates"),

                // NEW: Incident Verified
                citizenStage(
                    "citizen_verified_v2",
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

                // NEW: Report Rejected (v1.12.33), where it played the
                // general "Report updates" recording.
                citizenStage(
                    "citizen_rejected_v1",
                    "Report rejected",
                    R.raw.sound_rejected
                ),

                // v1.12.35: the same stages, vibrating. A channel's settings
                // are fixed once it exists, so they are new channels; backend
                // v1.12.27 names these, and the ones above stay for a server
                // that does not yet.
                citizenStage("citizen_verified_v3", "Incident verified", R.raw.sound_verified),
                citizenStage("citizen_on_route_v2", "Responders on route", R.raw.sound_on_route),
                citizenStage("citizen_on_scene_v2", "Responders on scene", R.raw.sound_on_scene),
                citizenStage("citizen_fire_out_v2", "Fire out", R.raw.sound_fire_out),
                citizenStage("citizen_rejected_v2", "Report rejected", R.raw.sound_rejected),

                // EXISTING: Silent reminders
                silent,

                // General notifications: the vibrating one, and the old one.
                updatesChannel("updates_v2"),
                updatesChannel("updates")
            )
        )
    }
}
