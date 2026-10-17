package com.kstkarus.iris.iris

import android.Manifest
import android.app.ActivityManager
import android.app.usage.StorageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.os.storage.StorageManager
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pictureInPicture: PictureInPictureController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        DownloadForegroundService.cancelEnd()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pictureInPicture = PictureInPictureController(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )

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
            val owner = call.argument<String>("owner")
                ?: DownloadForegroundService.OWNER_DOWNLOADS
            val channelName = call.argument<String>("channelName")
            val channelDescription = call.argument<String>("channelDescription")
            when (call.method) {
                "start" -> {
                    requestNotificationPermissionIfNeeded()
                    sendDownloadServiceAction(
                        DownloadForegroundService.ACTION_START,
                        title,
                        text,
                        owner,
                        channelName,
                        channelDescription,
                    )
                    result.success(null)
                }
                "update" -> {
                    // Not a service command: see DownloadForegroundService.
                    DownloadForegroundService.showNotification(
                        this,
                        owner,
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
                        owner,
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
            "iris/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstallPackages())
                "openInstallPermissionSettings" -> {
                    try {
                        openInstallPermissionSettings()
                        result.success(null)
                    } catch (error: AppUpdateInstallException) {
                        result.error(error.code, error.message, null)
                    } catch (error: ActivityNotFoundException) {
                        result.error("settings_unavailable", error.message, null)
                    } catch (error: Exception) {
                        result.error("permission_settings_failed", error.message, null)
                    }
                }
                "install" -> {
                    try {
                        installUpdate(call.argument<String>("path"))
                        result.success(null)
                    } catch (error: AppUpdateInstallException) {
                        result.error(error.code, error.message, null)
                    } catch (error: Exception) {
                        result.error("installer_error", error.message, null)
                    }
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

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        pictureInPicture?.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pictureInPicture?.onModeChanged(isInPictureInPictureMode)
    }

    override fun onDestroy() {
        pictureInPicture?.dispose()
        pictureInPicture = null
        val closing = isFinishing && !isChangingConfigurations
        super.onDestroy()
        // The Flutter engine went with the activity; see endWithApp.
        if (closing) DownloadForegroundService.endWithApp(this)
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

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        requireUpdateActivityResumed()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || canInstallPackages()) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    @Suppress("DEPRECATION")
    private fun installUpdate(path: String?) {
        if (!canInstallPackages()) {
            throw AppUpdateInstallException(
                "install_permission_required",
                "Allow Iris to install updates in Android settings.",
            )
        }
        requireUpdateActivityResumed()

        val apk = validatedUpdateApk(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(intent)
        } catch (error: ActivityNotFoundException) {
            throw AppUpdateInstallException(
                "installer_unavailable",
                error.message ?: "No installer is available.",
            )
        }
    }

    private fun requireUpdateActivityResumed() {
        if (
            isFinishing || isDestroyed ||
            !lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        ) {
            throw AppUpdateInstallException(
                "activity_not_foreground",
                "Open Iris before continuing the update.",
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun validatedUpdateApk(path: String?): File {
        if (path.isNullOrBlank()) {
            throw AppUpdateInstallException("invalid_apk", "The update APK path is missing.")
        }

        val updateDirectory = File(filesDir, "app_updates").canonicalFile
        val apk = File(path).canonicalFile
        if (
            !apk.path.startsWith(updateDirectory.path + File.separator) ||
            !apk.isFile || !apk.canRead() || apk.length() == 0L ||
            !apk.extension.equals("apk", ignoreCase = true)
        ) {
            throw AppUpdateInstallException("invalid_apk", "The update APK is invalid.")
        }

        val signingFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val archive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apk.path,
                PackageManager.PackageInfoFlags.of(signingFlag.toLong()),
            )
        } else {
            packageManager.getPackageArchiveInfo(apk.path, signingFlag)
        }
        if (archive?.packageName != packageName) {
            throw AppUpdateInstallException(
                "invalid_apk",
                "The APK does not belong to this Iris installation.",
            )
        }
        return apk
    }

    private fun sendDownloadServiceAction(
        action: String,
        title: String,
        text: String,
        owner: String,
        channelName: String?,
        channelDescription: String?,
    ) {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            this.action = action
            putExtra(DownloadForegroundService.EXTRA_TITLE, title)
            putExtra(DownloadForegroundService.EXTRA_TEXT, text)
            putExtra(DownloadForegroundService.EXTRA_OWNER, owner)
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
            try {
                startService(intent)
            } catch (_: IllegalStateException) {
                // A stop from the background with no service running: there
                // is nothing to stop, and Android refuses to start one.
            }
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

private class AppUpdateInstallException(
    val code: String,
    message: String,
) : Exception(message)
