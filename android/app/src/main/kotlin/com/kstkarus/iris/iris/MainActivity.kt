package com.kstkarus.iris.iris

import android.app.ActivityManager
import android.content.Context
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
}
