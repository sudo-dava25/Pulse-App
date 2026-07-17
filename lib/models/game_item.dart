/// Representasi satu game di daftar Pulse.
///
/// Sengaja hanya menyimpan [packageName] & [lastPlayed] secara persisten
/// (lewat [GameRepository]) - nama tampilan dan ikon selalu diambil ulang
/// dari `device_apps` saat dibutuhkan, supaya tidak perlu menyimpan bytes
/// ikon di SharedPreferences dan otomatis ikut update kalau game di-update.
class GameItem {
  final String packageName;
  final DateTime? lastPlayed;

  const GameItem({
    required this.packageName,
    this.lastPlayed,
  });

  GameItem copyWith({DateTime? lastPlayed}) => GameItem(
        packageName: packageName,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );
}
