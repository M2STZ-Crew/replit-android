package com.m2stz.replit

import android.Manifest
import android.annotation.SuppressLint
import android.app.DownloadManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.io.File

/**
 * "Check for updates" downloads through Android's DownloadManager (v1.12.48,
 * 17 Nov 2026: "add the background downloading when updating, because it can
 * be interrupted"). The download carries on with RepLiT in the background or
 * closed, shows its progress in the notification shade, and picks up after a
 * lost connection. The APK lands in the app's own external files
 * (files/updates), which the updates FileProvider shares with Android's
 * installer (res/xml/update_paths.xml). When it is done,
 * [UpdateDownloadReceiver] posts "The update is downloaded", whose tap opens
 * the sheet (lib/updates/app_updates.dart), which installs it.
 *
 * One download at a time: its id, file name and the finished notification's
 * words are kept in shared preferences, so they outlive the app's process.
 */
object UpdateDownloads {
    /** On MainActivity's intent from the finished notification. */
    const val EXTRA_OPEN = "replit_open"
    const val OPEN_UPDATES = "updates"

    private const val PREFS = "replit_update_download"
    private const val NOTIFICATION_ID = 41207
    private const val APK = "application/vnd.android.package-archive"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun manager(context: Context): DownloadManager? =
        context.getSystemService(DownloadManager::class.java)

    /** files/updates on the app's external storage; null without one. */
    fun dir(context: Context): File? =
        context.getExternalFilesDir("updates")?.apply { mkdirs() }

    /** Start downloading [url] into files/updates/[file]: its id. Throws
     *  when this phone cannot (no external storage, DownloadManager off). */
    fun start(
        context: Context,
        url: String,
        file: String,
        title: String,
        description: String,
        readyTitle: String,
        readyText: String,
        channel: String
    ): Long {
        val manager = manager(context) ?: throw IllegalStateException("No DownloadManager")
        val folder = dir(context) ?: throw IllegalStateException("No external files")
        require(url.startsWith("https://")) { "Not an https address" }
        require(file.isNotBlank() && !file.contains('/')) { "Not a file name" }
        // An earlier download goes, finished or not; and a file by this name,
        // which would make DownloadManager pick another name.
        pending(context)?.let { manager.remove(it) }
        File(folder, file).delete()
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription(description)
            .setMimeType(APK)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(context, "updates", file)
        val id = manager.enqueue(request)
        prefs(context).edit()
            .putLong("id", id)
            .putString("file", file)
            .putString("readyTitle", readyTitle)
            .putString("readyText", readyText)
            .putString("channel", channel)
            .apply()
        return id
    }

    /** The download under way, if any. */
    fun pending(context: Context): Long? {
        val id = prefs(context).getLong("id", -1L)
        return if (id >= 0L) id else null
    }

    /** The download under way, for Dart: its id and file name. */
    fun pendingInfo(context: Context): Map<String, Any?>? {
        val id = pending(context) ?: return null
        return mapOf("id" to id, "file" to prefs(context).getString("file", null))
    }

    /** Where download [id] is, or null when Android no longer has it. */
    fun status(context: Context, id: Long): Map<String, Any?>? {
        val manager = manager(context) ?: return null
        val cursor = manager.query(DownloadManager.Query().setFilterById(id)) ?: return null
        try {
            if (!cursor.moveToFirst()) return null
            val state = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val local: String? =
                cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            val name = when (state) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                else -> "failed"
            }
            val bytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            )
            val path: String? = if (local == null) null else Uri.parse(local).path
            return mapOf(
                "status" to name,
                "bytes" to bytes,
                "total" to total,
                "path" to path
            )
        } finally {
            cursor.close()
        }
    }

    /** Stop the download under way, with its file, and forget it. */
    fun cancel(context: Context) {
        pending(context)?.let { id -> manager(context)?.remove(id) }
        forget(context)
    }

    /** The download is used (handed to the installer) or gone. */
    fun forget(context: Context) {
        prefs(context).edit().clear().apply()
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** "The update is downloaded": its tap opens Check for updates. Not
     *  posted without permission to notify; the sheet says it anyway. */
    @SuppressLint("MissingPermission")
    fun notifyReady(context: Context) {
        val prefs = prefs(context)
        val title = prefs.getString("readyTitle", null) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val open = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN, OPEN_UPDATES)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(
            context,
            prefs.getString("channel", null) ?: "app_update_en_v1"
        )
            .setSmallIcon(R.drawable.ic_stat_replit)
            .setColor(ContextCompat.getColor(context, R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(prefs.getString("readyText", null) ?: "")
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // Notifications turned off for RepLiT: the sheet says it instead.
        }
    }
}

/** Told by DownloadManager that a download is done: when it is the update's,
 *  and whole, "The update is downloaded" goes up. */
class UpdateDownloadReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
        val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (id < 0L || id != UpdateDownloads.pending(context)) return
        if (UpdateDownloads.status(context, id)?.get("status") == "successful") {
            UpdateDownloads.notifyReady(context)
        }
    }
}
