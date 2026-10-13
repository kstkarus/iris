package com.kstkarus.iris.iris

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process

/**
 * Keeps the process alive while a download runs. Started only for
 * [ACTION_START]; progress goes straight to the notification through
 * [showNotification], never through `startForegroundService`, which would
 * oblige a service that is not in the foreground (stopped by Android 15's
 * dataSync limit, or never started from the background) to call
 * `startForeground` within seconds or have the app killed.
 */
class DownloadForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            running = false
            leaveForeground()
            // Not stopSelf(): a start sent right after this stop would find
            // its service destroyed under it. With the id, a newer start
            // keeps it.
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val notification = notification(
            this,
            title = intent?.getStringExtra(EXTRA_TITLE),
            text = intent?.getStringExtra(EXTRA_TEXT),
            channelName = intent?.getStringExtra(EXTRA_CHANNEL_NAME),
            channelDescription = intent?.getStringExtra(EXTRA_CHANNEL_DESCRIPTION),
        )
        running = true
        // Every command but stop came through startForegroundService.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Swiped away from the recent apps: the activity and the Dart side that
     * ran the downloads are gone, and nothing would ever stop this service
     * or the native torrent session in the process. Both end here; the
     * queue picks up again from the registry on the next launch.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        endWithApp(this)
        super.onTaskRemoved(rootIntent)
    }

    private fun leaveForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        stopSelf(startId)
    }

    companion object {
        const val ACTION_START = "iris.download.START"
        const val ACTION_STOP = "iris.download.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_CHANNEL_DESCRIPTION = "channelDescription"

        private const val CHANNEL_ID = "iris_downloads"
        private const val NOTIFICATION_ID = 7101

        /**
         * The app is closed for good (its last activity finished, or its
         * task was swiped away) while the Dart side that ran the downloads
         * is gone: the notification, the service and the process go, so no
         * native torrent session goes on unowned, nor a second one starts
         * beside it on the next launch.
         */
        fun endWithApp(context: Context) {
            if (!running) return
            running = false
            cancelNotification(context)
            context.stopService(Intent(context, DownloadForegroundService::class.java))
            // A moment for writes the app queued on its way out (preferences
            // are saved in the background) to land.
            Handler(Looper.getMainLooper()).postDelayed(
                { Process.killProcess(Process.myPid()) },
                EXIT_DELAY_MS,
            )
        }

        /** Whether a download holds the service, so the process with it. */
        @Volatile
        private var running = false

        private const val EXIT_DELAY_MS = 500L

        /** Updates the download notification, whether or not the service runs. */
        fun showNotification(
            context: Context,
            title: String?,
            text: String?,
            channelName: String?,
            channelDescription: String?,
        ) {
            notificationManager(context).notify(
                NOTIFICATION_ID,
                notification(context, title, text, channelName, channelDescription),
            )
        }

        /** Takes the notification away, also one shown without the service. */
        fun cancelNotification(context: Context) {
            notificationManager(context).cancel(NOTIFICATION_ID)
        }

        private fun notificationManager(context: Context): NotificationManager =
            context.getSystemService(NotificationManager::class.java)

        private fun notification(
            context: Context,
            title: String?,
            text: String?,
            channelName: String?,
            channelDescription: String?,
        ): Notification {
            // Created every time: re-creating an existing channel updates its
            // name and description to the app's current language.
            createNotificationChannel(
                context,
                name = channelName ?: "Загрузки",
                description = channelDescription
                    ?: "Ход загрузки контента для офлайн-просмотра",
            )
            return buildNotification(
                context,
                title = title ?: "Iris",
                text = text ?: "Загрузка контента",
            )
        }

        private fun createNotificationChannel(
            context: Context,
            name: String,
            description: String,
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            notificationManager(context).createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    name,
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    this.description = description
                    setShowBadge(false)
                },
            )
        }

        private fun buildNotification(
            context: Context,
            title: String,
            text: String,
        ): Notification {
            val openAppIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            return builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(pendingIntent)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_PROGRESS)
                .build()
        }
    }
}
