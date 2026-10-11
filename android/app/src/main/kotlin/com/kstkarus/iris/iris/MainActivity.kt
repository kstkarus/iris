package com.kstkarus.iris.iris

import android.app.ActivityManager
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.os.storage.StorageManager
import android.app.usage.StorageStatsManager
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "iris/player_runtime_stats",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppMemoryBytes" -> result.success(readAppMemoryBytes())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "iris/download_service",
        ).setMethodCallHandler { call, result ->
            val title = call.argument<String>("title") ?: "Iris"
            val text = call.argument<String>("text") ?: "Загрузка контента"
            val channelName = call.argument<String>("channelName")
            val channelDescription = call.argument<String>("channelDescription")
            when (call.method) {
                "start" -> {
                    requestNotificationPermissionIfNeeded()
                    sendDownloadServiceAction(
                        DownloadForegroundService.ACTION_START,
                        title,
                        text,
                        channelName,
                        channelDescription,
                    )
                    result.success(null)
                }
                "update" -> {
                    sendDownloadServiceAction(
                        DownloadForegroundService.ACTION_UPDATE,
                        title,
                        text,
                        channelName,
                        channelDescription,
                    )
                    result.success(null)
                }
                "stop" -> {
                    sendDownloadServiceAction(
                        DownloadForegroundService.ACTION_STOP,
                        title,
                        text,
                        channelName,
                        channelDescription,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "iris/app_storage_stats",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsage" -> result.success(readAppStorageUsage())
                else -> result.notImplemented()
            }
        }
    }

    private fun readAppMemoryBytes(): Long {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = activityManager.getProcessMemoryInfo(
            intArrayOf(android.os.Process.myPid()),
        )
        val totalPssKb = memoryInfo.firstOrNull()?.totalPss ?: 0
        return totalPssKb.toLong() * 1024L
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
        }
    }

    private fun sendDownloadServiceAction(
        action: String,
        title: String,
        text: String,
        channelName: String?,
        channelDescription: String?,
    ) {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            this.action = action
            putExtra(DownloadForegroundService.EXTRA_TITLE, title)
            putExtra(DownloadForegroundService.EXTRA_TEXT, text)
            putExtra(DownloadForegroundService.EXTRA_CHANNEL_NAME, channelName)
            putExtra(
                DownloadForegroundService.EXTRA_CHANNEL_DESCRIPTION,
                channelDescription,
            )
        }
        if (
            action != DownloadForegroundService.ACTION_STOP &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        ) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun readAppStorageUsage(): Map<String, Long> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val manager = getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
                val stats = manager.queryStatsForUid(StorageManager.UUID_DEFAULT, Process.myUid())
                return mapOf(
                    "appBytes" to stats.appBytes,
                    "dataBytes" to stats.dataBytes,
                    "cacheBytes" to stats.cacheBytes,
                    "totalBytes" to stats.appBytes + stats.dataBytes,
                )
            } catch (_: Exception) {
                // Fall back to a direct directory scan below.
            }
        }

        val appBytes = File(applicationInfo.sourceDir).length() +
            (applicationInfo.splitSourceDirs?.sumOf { File(it).length() } ?: 0L)
        val dataRoot = filesDir.parentFile
        val dataBytes = dataRoot?.directorySize() ?: 0L
        val cacheBytes = cacheDir.directorySize()
        return mapOf(
            "appBytes" to appBytes,
            "dataBytes" to dataBytes,
            "cacheBytes" to cacheBytes,
            "totalBytes" to appBytes + dataBytes,
        )
    }

    private fun File.directorySize(): Long {
        if (!exists()) return 0L
        if (isFile) return length()
        return listFiles()?.sumOf { it.directorySize() } ?: 0L
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 710
    }
}
