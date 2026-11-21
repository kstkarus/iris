package com.kstkarus.iris.iris

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class PlayerMediaSessionController(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "iris/player_media_controls")
    private val notifications = activity.getSystemService(NotificationManager::class.java)
    private var sessionId: Long? = null
    private var session: MediaSession? = null
    private var registered = false
    private var metadata: Triple<String, String, Long>? = null
    private var notificationState: NotificationState? = null
    private val notificationIntents = mutableMapOf<String, PendingIntent>()

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = sessionId ?: return
            when (intent.action) {
                AudioManager.ACTION_AUDIO_BECOMING_NOISY -> send(id, "pauseImmediately")
                ACTION_TRANSPORT -> {
                    if (intent.getLongExtra("session", 0) != id) return
                    val method = intent.getStringExtra("method") ?: return
                    send(id, method)
                }
            }
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "update" && call.method != "deactivate") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val id = call.argument<Number>("session")?.toLong()
            if (id == null || id <= 0) {
                result.error("invalid_session", "Expected a player session ID.", null)
                return@setMethodCallHandler
            }
            if (call.method == "deactivate") {
                if (sessionId == id) deactivate()
            } else {
                if (sessionId != id) activate(id)
                update(
                    title = call.argument<String>("title").orEmpty(),
                    episode = call.argument<String>("episode").orEmpty(),
                    duration = call.argument<Number>("durationMs")?.toLong()?.coerceAtLeast(0) ?: 0,
                    position = call.argument<Number>("positionMs")?.toLong()?.coerceAtLeast(0) ?: 0,
                    rate = call.argument<Number>("rate")?.toFloat() ?: 1f,
                    playing = call.argument<Boolean>("playing") == true,
                    buffering = call.argument<Boolean>("buffering") == true,
                    canNext = call.argument<Boolean>("canNext") == true,
                )
            }
            result.success(null)
        }
    }

    private fun activate(id: Long) {
        deactivate()
        sessionId = id
        session = MediaSession(activity, "IrisPlayer").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = send(id, "play")
                override fun onPause() = send(id, "pause")
                override fun onSkipToNext() = send(id, "next")
                override fun onFastForward() = send(id, "seekForward")
                override fun onRewind() = send(id, "seekBackward")
                override fun onSeekTo(pos: Long) = send(id, "seekTo", pos)

                override fun onCustomAction(action: String, extras: Bundle?) {
                    when (action) {
                        "pause" -> onPause()
                        "seekForward" -> onFastForward()
                        "seekBackward" -> onRewind()
                    }
                }
            })
            setSessionActivity(
                PendingIntent.getActivity(
                    activity, 0,
                    Intent(activity, activity.javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        registerReceiver()
    }

    private fun update(
        title: String,
        episode: String,
        duration: Long,
        position: Long,
        rate: Float,
        playing: Boolean,
        buffering: Boolean,
        canNext: Boolean,
    ) {
        val active = session ?: return
        val canSeek = duration > 0
        val description = Triple(title, episode, duration)
        if (description != metadata) {
            active.setMetadata(
                MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, episode)
                    .putLong(MediaMetadata.METADATA_KEY_DURATION, duration)
                    .build(),
            )
            metadata = description
        }

        val state = when {
            !playing -> PlaybackState.STATE_PAUSED
            buffering -> PlaybackState.STATE_BUFFERING
            else -> PlaybackState.STATE_PLAYING
        }
        var actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE
        if (canSeek) actions = actions or PlaybackState.ACTION_SEEK_TO or
            PlaybackState.ACTION_FAST_FORWARD or PlaybackState.ACTION_REWIND
        if (canNext) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT
        val playback = PlaybackState.Builder()
            .setActions(actions)
            .setState(
                state, position, if (state == PlaybackState.STATE_PLAYING) rate else 0f,
                SystemClock.elapsedRealtime(),
            )
        // Android 13 builds its buttons from PlaybackState. The standard
        // fast-forward/rewind actions still serve hardware and older devices.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (state == PlaybackState.STATE_BUFFERING) {
                // The system puts a spinner in the normal play/pause slot.
                playback.addCustomAction("pause", activity.getString(R.string.media_pause), R.drawable.ic_pip_pause)
            }
            if (canSeek) {
                playback.addCustomAction("seekBackward", activity.getString(R.string.media_seek_backward), android.R.drawable.ic_media_rew)
                playback.addCustomAction("seekForward", activity.getString(R.string.media_seek_forward), android.R.drawable.ic_media_ff)
            }
        }
        active.setPlaybackState(playback.build())
        if (!active.isActive) active.isActive = true

        val nextNotification = NotificationState(title, episode, playing, canSeek, canNext)
        if (nextNotification != notificationState) {
            publishNotification(active, nextNotification)
            notificationState = nextNotification
        }
    }

    @SuppressLint("MissingPermission") // Notifications with a media session token are exempt.
    private fun publishNotification(active: MediaSession, state: NotificationState) {
        notifications.createNotificationChannel(
            NotificationChannel(NOTIFICATION_CHANNEL, activity.getString(R.string.media_playback), NotificationManager.IMPORTANCE_LOW),
        )
        val style = Notification.MediaStyle().setMediaSession(active.sessionToken)
        val builder = Notification.Builder(activity, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(state.title)
            .setContentText(state.episode)
            .setContentIntent(active.controller.sessionActivity)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setStyle(style)

        var count = 0
        fun addAction(method: String, label: Int, icon: Int) {
            val pending = notificationIntents.getOrPut(method) {
                PendingIntent.getBroadcast(
                    activity, notificationIntents.size,
                    Intent(ACTION_TRANSPORT).setPackage(activity.packageName)
                        .putExtra("session", sessionId ?: 0L).putExtra("method", method),
                    PendingIntent.FLAG_IMMUTABLE,
                )
            }
            builder.addAction(
                Notification.Action.Builder(Icon.createWithResource(activity, icon), activity.getString(label), pending).build(),
            )
            count++
        }
        if (state.canSeek) addAction("seekBackward", R.string.media_seek_backward, android.R.drawable.ic_media_rew)
        if (state.playing) addAction("pause", R.string.media_pause, R.drawable.ic_pip_pause)
        else addAction("play", R.string.media_play, R.drawable.ic_pip_play)
        if (state.canNext) addAction("next", R.string.media_next, android.R.drawable.ic_media_next)
        if (state.canSeek) addAction("seekForward", R.string.media_seek_forward, android.R.drawable.ic_media_ff)
        style.setShowActionsInCompactView(*IntArray(minOf(count, 3)) { it })
        notifications.notify(NOTIFICATION_ID, builder.build())
    }

    private fun send(id: Long, method: String, position: Long? = null) {
        if (id != sessionId) return
        channel.invokeMethod(method, mapOf("session" to id, "positionMs" to position))
    }

    private fun registerReceiver() {
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY).apply {
            addAction(ACTION_TRANSPORT)
        }
        ContextCompat.registerReceiver(activity, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        registered = true
    }

    private fun deactivate() {
        sessionId = null
        if (registered) {
            activity.unregisterReceiver(receiver)
            registered = false
        }
        if (session != null) notifications.cancel(NOTIFICATION_ID)
        notificationIntents.values.forEach { it.cancel() }
        notificationIntents.clear()
        session?.apply {
            isActive = false
            release()
        }
        session = null
        metadata = null
        notificationState = null
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        deactivate()
    }

    private data class NotificationState(
        val title: String,
        val episode: String,
        val playing: Boolean,
        val canSeek: Boolean,
        val canNext: Boolean,
    )

    companion object {
        private const val ACTION_TRANSPORT = "com.kstkarus.iris.PLAYER_TRANSPORT"
        private const val NOTIFICATION_CHANNEL = "iris_player"
        private const val NOTIFICATION_ID = 7102
    }
}
