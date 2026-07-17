import 'root_shell.dart';

/// Deteksi package yang sedang di foreground.
///
/// Dipakai sebagai "jaring pengaman" setelah game di-launch dari tab
/// Game: begitu Pulse mendeteksi foreground BUKAN lagi package target
/// (user pencet Home/Recents/keluar), pemanggil (biasanya
/// [OverlayController]) tahu kapan harus menyembunyikan overlay &
/// menghentikan polling metrics.
class ForegroundWatcher {
  ForegroundWatcher._();

  static Future<String?> currentForegroundPackage() async {
    // mResumedActivity biasanya berformat:
    // "... mResumedActivity: ActivityRecord{... com.game.package/.MainActivity ...}"
    final raw = await RootShell.exec(
      'dumpsys activity activities | grep mResumedActivity',
    );
    final match = RegExp(r'\s([a-zA-Z0-9_.]+)/[a-zA-Z0-9_.$]+[}\s]').firstMatch(raw);
    if (match != null) return match.group(1);

    // Fallback ke mCurrentFocus dari dumpsys window kalau format di atas
    // tidak ketemu (bervariasi antar versi/vendor Android).
    final fallbackRaw = await RootShell.exec(
      'dumpsys window windows | grep mCurrentFocus',
    );
    final fallbackMatch =
        RegExp(r'\s([a-zA-Z0-9_.]+)/[a-zA-Z0-9_.$]+[}\s]').firstMatch(fallbackRaw);
    return fallbackMatch?.group(1);
  }
}
