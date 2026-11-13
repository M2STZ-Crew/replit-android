
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
     * RepLiT's notification channels.
     *
     * Android fixes a channel's sound and vibration when it is first made, so
     * a new recording, or a channel that plays the wrong one, needs a new id
     * (the server names the same ids: app/integrations/fcm.py in
     * replit-backend, SOUND_CHANNELS_V2).
     *
     * v1.12.42 (13 November 2026: "check all of the sounds and apply it to
     * the new. because we found some errors in sound"): every sound anew.
     * Channels made before v1.12.23 hold their recording by resource number,
     * and every file added to res/raw since renumbered the ones after it: on
     * a phone that had the app that early, "alert_medical" played fire out
     * and "alert_police" medical, and those ids were never made again. So
     * every sound channel this app ever made is deleted here, and each sound
     * gets a new channel that names its file, which no renumbering moves.
     * The recordings are the ones in NOTIFICATION SOUNDS, by who hears them:
     * staff the new incident of their agency (fire, police, medical,
     * barangay); residents a fire near them ("01 NEARBY INCIDENT", which also
     * plays for their other news), the stages of their report (02 to 05,
     * rejected) and their National ID's result (ID VERIFIED, ID NOT
     * VERIFIED); everyone "New Update!" in their language. Nothing plays the
     * phone's own tone: a push whose channel this phone does not have lands
     * on "general_v1" (AndroidManifest.xml), which plays the residents'.
     * silent_ping only vibrates, as before.
     */
    private fun createNotificationChannels() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager =
            getSystemService(NotificationManager::class.java) ?: return

        // Every sound channel an earlier version made: some hold their
        // recording by number, and the server names none of them for this
        // version.
        for (id in RETIRED_CHANNELS) manager.deleteNotificationChannel(id)

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

        // A channel that plays [raw] and vibrates; an urgent one also lights
        // up and shows on the lock screen.
        fun channel(
            id: String,
            name: String,
            about: String,
            raw: Int,
            urgent: Boolean = false
        ) = NotificationChannel(
            id,
            name,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = about

            setSound(sound(raw), attributes)

            enableVibration(true)

            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)

            if (urgent) {
                enableLights(true)

                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        }

        // Reminders of a new fire not yet opened: vibration only.
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

        val stage = "Updates about a fire incident you reported."
        val nationalId = "The result of your National ID check."
        val update = "A new version of RepLiT is ready to install."

        manager.createNotificationChannels(
            listOf(
                // Staff: a new incident, in their agency's recording.
                channel(
                    "alert_fire_v2",
                    "Fire alerts",
                    "Fires, for Fire Volunteers and BFP.",
                    R.raw.sound_fire,
                    urgent = true
                ),
                channel(
                    "alert_police_v2",
                    "Police alerts",
                    "Incidents that asked for the police.",
                    R.raw.sound_police,
                    urgent = true
                ),
                channel(
                    "alert_medical_v2",
                    "Medical alerts",
                    "Incidents that asked for a medical team.",
                    R.raw.sound_medical,
                    urgent = true
                ),
                channel(
                    "alert_barangay_v2",
                    "Barangay alerts",
                    "Incidents that asked for the barangay.",
                    R.raw.sound_barangay,
                    urgent = true
                ),

                // Residents: a fire near them, and their other news.
                channel(
                    "citizen_nearby_v1",
                    "Fires near you",
                    "A fire reported near you, and other news about your reports.",
                    R.raw.sound_citizen,
                    urgent = true
                ),

                // Residents: the stages of their report.
                channel("citizen_verified_v4", "Report acknowledged", stage, R.raw.sound_verified),
                channel("citizen_on_route_v3", "Responders on route", stage, R.raw.sound_on_route),
                channel("citizen_on_scene_v3", "Responders on scene", stage, R.raw.sound_on_scene),
                channel("citizen_fire_out_v3", "Fire out", stage, R.raw.sound_fire_out),
                channel("citizen_rejected_v3", "Report rejected", stage, R.raw.sound_rejected),

                // Residents: their National ID's result.
                channel("id_verified_v1", "National ID verified", nationalId, R.raw.sound_id_verified),
                channel("id_rejected_v1", "National ID not verified", nationalId, R.raw.sound_id_rejected),

                // Everyone: "New Update!" in their language (made by name in
                // v1.12.38, so they stay).
                channel("app_update_en_v1", "App updates (English)", update, R.raw.update_en),
                channel("app_update_tl_v1", "App updates (Tagalog)", update, R.raw.update_tl),

                // A push naming a channel this phone does not have: the
                // residents' recording, never the phone's tone.
                channel(
                    "general_v1",
                    "Other notifications",
                    "Anything else RepLiT tells you.",
                    R.raw.sound_citizen
                ),

                silent
            )
        )
    }

    companion object {
        /** Every sound channel an earlier version of the app made. */
        val RETIRED_CHANNELS = listOf(
            "fire_alerts",
            "alert_fire",
            "alert_police",
            "alert_medical",
            "alert_barangay",
            "citizen_updates",
            "citizen_updates_v2",
            "citizen_verified_v1",
            "citizen_verified_v2",
            "citizen_verified_v3",
            "citizen_on_route_v1",
            "citizen_on_route_v2",
            "citizen_on_scene_v1",
            "citizen_on_scene_v2",
            "citizen_fire_out_v1",
            "citizen_fire_out_v2",
            "citizen_rejected_v1",
            "citizen_rejected_v2",
            "updates",
            "updates_v2",
            "app_updates_v1"
        )
    }
}
