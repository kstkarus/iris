package com.kstkarus.iris.iris

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

internal class TorrentFilePicker(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private data class Request(val maxBytes: Int, val result: MethodChannel.Result)

    private val channel = MethodChannel(messenger, "iris/torrent_file_picker")
    private var pending: Request? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickTorrentFile" -> pick(call.arguments as? Int, result)
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun pick(maxBytes: Int?, result: MethodChannel.Result) {
        if (maxBytes == null || maxBytes <= 0 || maxBytes == Int.MAX_VALUE || pending != null) {
            result.error("file_picker_unavailable", null, null)
            return
        }
        pending = Request(maxBytes, result)
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (_: Exception) {
            pending = null
            result.error("file_picker_unavailable", null, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val request = pending ?: return
        if (resultCode != Activity.RESULT_OK) {
            complete(request) { success(null) }
            return
        }
        val uri = data?.data
        if (uri == null) {
            complete(request) { error("file_read_failed", null, null) }
            return
        }
        val resolver = activity.applicationContext.contentResolver
        Thread({
            try {
                val bytes = resolver.openInputStream(uri)?.use {
                    readTorrentFile(it, request.maxBytes)
                }
                activity.runOnUiThread {
                    complete(request) {
                        if (bytes == null) error("file_read_failed", null, null) else success(bytes)
                    }
                }
            } catch (_: TorrentFileTooLargeException) {
                activity.runOnUiThread { complete(request) { error("file_too_large", null, null) } }
            } catch (_: Exception) {
                activity.runOnUiThread { complete(request) { error("file_read_failed", null, null) } }
            }
        }, "iris-torrent-file").start()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.let { complete(it) { success(null) } }
    }

    private fun complete(request: Request, reply: MethodChannel.Result.() -> Unit) {
        if (pending !== request) return
        pending = null
        request.result.reply()
    }

    private companion object {
        const val REQUEST_CODE = 6407
    }
}

internal class TorrentFileTooLargeException : Exception()

internal fun readTorrentFile(input: InputStream, maxBytes: Int): ByteArray {
    val output = ByteArrayOutputStream()
    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
    while (true) {
        val remaining = maxBytes - output.size()
        val read = input.read(buffer, 0, minOf(buffer.size, remaining + 1))
        if (read == -1) return output.toByteArray()
        if (read > remaining) throw TorrentFileTooLargeException()
        output.write(buffer, 0, read)
    }
}
