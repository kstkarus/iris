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
 * Keeps the process alive while a download or update runs. Started only for
 * [ACTION_START]; progress goes straight to the notification through
 * [showNotification], never through `startForegroundService`, which would
 * oblige a service that is not in the foreground (stopped by Android 15's
 * dataSync limit, or never started from the background) to call
 * `startForeground` within seconds or have the app killed.
 */
class DownloadForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopOwner(this, ownerOf(intent), startId)
            return START_NOT_STICKY
        }

        val owner = ownerOf(intent)
        owners[owner] = OwnerState(
            notification = notificationState(
                title = intent?.getStringExtra(EXTRA_TITLE),
                text = intent?.getStringExtra(EXTRA_TEXT),
                channelName = intent?.getStringExtra(EXTRA_CHANNEL_NAME),
                channelDescription = intent?.getStringExtra(EXTRA_CHANNEL_DESCRIPTION),
            ),
            active = true,
        )
        val notification = buildCurrentNotification(this)
        foreground = true
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
     * that owned foreground work is gone, and nothing would ever stop this service
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
        foreground = false
        deactivateOwners()
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        foreground = false
        deactivateOwners()
        stopSelf(startId)
    }

    companion object {
        const val ACTION_START = "iris.download.START"
        const val ACTION_STOP = "iris.download.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_CHANNEL_DESCRIPTION = "channelDescription"
        const val EXTRA_OWNER = "owner"
        const val OWNER_DOWNLOADS = "downloads"
        const val OWNER_APP_UPDATE = "app_update"

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
            val wasForeground = foreground
            owners.clear()
            cancelNotification(context)
            if (!wasForeground) return
            foreground = false
            context.stopService(Intent(context, DownloadForegroundService::class.java))
            // A moment for writes the app queued on its way out (preferences
            // are saved in the background) to land.
            exitHandler.postDelayed(exit, EXIT_DELAY_MS)
        }

        /** The app opened again within that moment: it stays. */
        fun cancelEnd() {
            exitHandler.removeCallbacks(exit)
        }

        private val exitHandler by lazy { Handler(Looper.getMainLooper()) }
        private val exit = Runnable { Process.killProcess(Process.myPid()) }

        private data class NotificationState(
            val title: String?,
            val text: String?,
            val channelName: String?,
            val channelDescription: String?,
        )

        private data class OwnerState(
            val notification: NotificationState,
            val active: Boolean,
        )

        private val owners = mutableMapOf<String, OwnerState>()

        /** Whether an owner currently holds the service, so the process with it. */
        @Volatile
        private var foreground = false

        private const val EXIT_DELAY_MS = 500L

        /** Updates one owner's notification without starting the service. */
        fun showNotification(
            context: Context,
            owner: String,
            title: String?,
            text: String?,
            channelName: String?,
            channelDescription: String?,
        ) {
            val normalizedOwner = normalizeOwner(owner)
            val current = owners[normalizedOwner]
            owners[normalizedOwner] = OwnerState(
                notification = notificationState(title, text, channelName, channelDescription),
                active = current?.active ?: false,
            )
            showCurrentNotification(context)
        }

        private fun stopOwner(
            service: DownloadForegroundService,
            owner: String,
            startId: Int,
        ) {
            owners.remove(owner)
            if (owners.values.none { it.active }) {
                if (foreground) {
                    service.leaveForeground()
                    foreground = false
                }
                if (owners.isEmpty()) {
                    cancelNotification(service)
                } else {
                    showCurrentNotification(service)
                }
                // Not stopSelf(): a newer start must be allowed to keep this service.
                service.stopSelf(startId)
                return
            }
            showCurrentNotification(service)
        }

        private fun buildCurrentNotification(context: Context): Notification {
            val state = visibleState()?.notification
            return notification(
                context,
                title = state?.title,
                text = state?.text,
                channelName = state?.channelName,
                channelDescription = state?.channelDescription,
            )
        }

        private fun showCurrentNotification(context: Context) {
            notificationManager(context).notify(NOTIFICATION_ID, buildCurrentNotification(context))
        }

        private fun visibleState(): OwnerState? =
            owners[OWNER_APP_UPDATE] ?: owners[OWNER_DOWNLOADS]

        private fun deactivateOwners() {
            owners.keys.toList().forEach { owner ->
                owners[owner]?.let { owners[owner] = it.copy(active = false) }
            }
        }

        private fun ownerOf(intent: Intent?): String =
            normalizeOwner(intent?.getStringExtra(EXTRA_OWNER))

        private fun normalizeOwner(owner: String?): String =
            if (owner == OWNER_APP_UPDATE) OWNER_APP_UPDATE else OWNER_DOWNLOADS

        private fun notificationState(
            title: String?,
            text: String?,
            channelName: String?,
            channelDescription: String?,
        ) = NotificationState(title, text, channelName, channelDescription)

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
