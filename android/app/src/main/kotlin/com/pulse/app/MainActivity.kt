package com.pulse.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * Satu-satunya titik di sisi native yang menjalankan perintah shell
 * lewat `su`. Semua pemanggilan dari Dart (lihat RootShell di
 * lib/services/root_shell.dart) masuk lewat MethodChannel "pulse/root".
 *
 * CATATAN: proses `su -c ...` dijalankan secara síncron di background
 * thread bawaan MethodChannel handler Flutter (bukan main thread UI),
 * jadi aman dari sisi ANR - tapi tetap beri timeout supaya satu
 * perintah yang macet tidak menggantung sesi polling selamanya.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "pulse/root"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
