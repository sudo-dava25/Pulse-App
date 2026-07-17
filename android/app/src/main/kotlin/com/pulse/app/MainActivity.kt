package com.pulse.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * Satu-satunya titik di sisi native yang menjalankan perintah shell
 * lewat `su`. Semua pemanggilan dari Dart (lihat RootShell di
 * lib/services/root_shell.dart) masuk lewat MethodChannel "pulse/root".
 *
 * PENTING: MethodChannel ini SENGAJA dipasang dengan background
 * TaskQueue (`messenger.makeBackgroundTaskQueue()`). Tanpa ini, handler
 * `setMethodCallHandler` berjalan di UI thread utama Android secara
 * default - artinya setiap kali `su -c ...` dipanggil (bisa makan
 * waktu ratusan ms), seluruh UI Flutter ikut freeze/nge-lag. Ini salah
 * satu penyebab utama app terasa "berat" sebelum diperbaiki.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "pulse/root"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger: BinaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        val backgroundTaskQueue = messenger.makeBackgroundTaskQueue()

        MethodChannel(
            messenger,
            CHANNEL,
            StandardMethodCodec.INSTANCE,
            backgroundTaskQueue,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkRoot" -> result.success(checkRoot())
                "exec" -> {
                    val cmd = call.argument<String>("command") ?: ""
                    result.success(runAsRoot(cmd))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkRoot(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            val finished = process.waitFor(3, TimeUnit.SECONDS)
            if (!finished) {
                process.destroy()
                return false
            }
            val output = BufferedReader(InputStreamReader(process.inputStream)).readText()
            output.contains("uid=0")
        } catch (e: Exception) {
            false
        }
    }

    private fun runAsRoot(command: String): String {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
            val finished = process.waitFor(3, TimeUnit.SECONDS)
            if (!finished) {
                process.destroy()
                return ""
            }
            val output = BufferedReader(InputStreamReader(process.inputStream)).readText()
            if (output.isNotEmpty()) {
                output
            } else {
                BufferedReader(InputStreamReader(process.errorStream)).readText()
            }
        } catch (e: Exception) {
            ""
        }
    }
}
