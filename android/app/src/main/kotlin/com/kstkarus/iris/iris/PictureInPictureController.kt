package com.kstkarus.iris.iris

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * The player's picture in picture (Android 8 and later), driven from Dart
 * over `iris/picture_in_picture`. Dart says what plays; the activity
 * reports the mode back, and the play/pause button pressed in the window.
 */
class PictureInPictureController(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    /** A player page is open; only then does leaving the app open the window. */
    private var playerOpen = false
    private var playing = false
    private var aspectRatio: Rational? = null
    private var playLabel = "Play"
    private var pauseLabel = "Pause"

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_PLAY_PAUSE) {
                channel.invokeMethod("playPause", null)
            }
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "setPlayer" -> {
                    playerOpen = true
                    playing = call.argument<Boolean>("playing") ?: false
                    aspectRatio = call.argument<Double>("aspectRatio")?.let(::rationalOf)
                    call.argument<String>("playLabel")?.let { playLabel = it }
                    call.argument<String>("pauseLabel")?.let { pauseLabel = it }
                    applyParams()
                    result.success(null)
                }
                "clearPlayer" -> {
                    playerOpen = false
                    playing = false
                    applyParams()
                    result.success(null)
                }
                "enter" -> result.success(enter())
                else -> result.notImplemented()
            }
        }
        registerReceiver()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        try {
            activity.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Never registered.
        }
    }

    /** Before Android 12, the system does not enter by itself. */
    fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && playerOpen && playing) {
            enter()
        }
    }

    fun onModeChanged(active: Boolean) {
        // Closed rather than expanded: the activity has already stopped.
        val dismissed =
            !active && !activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
        channel.invokeMethod(
            "modeChanged",
            mapOf("active" to active, "dismissed" to dismissed),
        )
    }

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enter(): Boolean {
        if (!isSupported()) return false
        return try {
            activity.enterPictureInPictureMode(buildParams())
        } catch (_: IllegalStateException) {
            // Turned off for the app in the system's settings.
            false
        }
    }

    private fun applyParams() {
        if (!isSupported()) return
        try {
            activity.setPictureInPictureParams(buildParams())
        } catch (_: IllegalStateException) {
            // Turned off for the app; nothing to prepare.
        }
    }

    @SuppressLint("NewApi")
    private fun buildParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        aspectRatio?.let { builder.setAspectRatio(it) }
        builder.setActions(listOf(playPauseAction()))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(playerOpen && playing)
            builder.setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    @SuppressLint("NewApi")
    private fun playPauseAction(): RemoteAction {
        val label = if (playing) pauseLabel else playLabel
        val icon = Icon.createWithResource(
            activity,
            if (playing) R.drawable.ic_pip_pause else R.drawable.ic_pip_play,
        )
        val intent = PendingIntent.getBroadcast(
            activity,
            0,
            Intent(ACTION_PLAY_PAUSE).setPackage(activity.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return RemoteAction(icon, label, label, intent)
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    private fun registerReceiver() {
        val filter = IntentFilter(ACTION_PLAY_PAUSE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter)
        }
    }

    /** Within what Android accepts (1:2.39 to 2.39:1), a little inside. */
    private fun rationalOf(ratio: Double): Rational? {
        if (ratio.isNaN() || ratio <= 0) return null
        val clamped = ratio.coerceIn(1 / MAX_RATIO, MAX_RATIO)
        return Rational((clamped * 1000).roundToInt(), 1000)
    }

    companion object {
        private const val CHANNEL = "iris/picture_in_picture"
        private const val ACTION_PLAY_PAUSE = "com.kstkarus.iris.PIP_PLAY_PAUSE"
        private const val MAX_RATIO = 2.38
    }
}
