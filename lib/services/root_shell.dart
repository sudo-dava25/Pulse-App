import 'package:flutter/services.dart';

/// Jembatan ke sisi native (MainActivity.kt) yang menjalankan perintah
/// lewat `su -c "..."`. Semua akses root di app ini SELALU lewat kelas
/// ini - tidak ada tempat lain yang memanggil shell secara langsung -
/// supaya kalau nanti perlu logging/rate-limit/error-handling terpusat,
/// cukup diubah di satu tempat.
class RootShell {
  RootShell._();

  static const MethodChannel _channel = MethodChannel('pulse/root');

  static bool? _rootCached;

  /// Cek ketersediaan root. Hasilnya di-cache di memori (bukan
  /// SharedPreferences) supaya kalau device di-reboot tanpa root
  /// aktif (misal Magisk dicabut), status ikut ke-refresh saat app
  /// dibuka ulang.
  static Future<bool> isRootAvailable({bool forceRecheck = false}) async {
    if (_rootCached != null && !forceRecheck) return _rootCached!;
    try {
      final result = await _channel.invokeMethod<bool>('checkRoot');
      _rootCached = result ?? false;
    } on PlatformException {
      _rootCached = false;
    }
    return _rootCached!;
  }

  /// Jalankan satu perintah lewat `su -c`. Mengembalikan stdout (atau
  /// stderr kalau stdout kosong) sebagai String, atau string kosong
  /// kalau gagal/timeout - dibuat "gagal senyap" karena dipanggil
  /// berulang dalam loop polling, supaya satu perintah yang gagal
  /// tidak melempar exception yang mematikan seluruh sesi monitoring.
  static Future<String> exec(String command) async {
    try {
      final result = await _channel.invokeMethod<String>('exec', {
        'command': command,
      });
      return result ?? '';
    } on PlatformException {
      return '';
    }
  }
}
