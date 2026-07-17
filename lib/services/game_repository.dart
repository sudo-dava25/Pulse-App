import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_item.dart';

/// Menyimpan daftar package game yang ditambahkan user, plus kapan
/// terakhir dimainkan (lewat Pulse). Nama tampilan & ikon sengaja TIDAK
/// disimpan di sini - selalu diambil langsung dari `device_apps` saat
/// dirender, supaya selalu sinkron dengan data aplikasi yang sebenarnya.
class GameRepository {
  static const _kPackagesKey = 'pulse_game_packages';
  static const _kLastPlayedPrefix = 'pulse_last_played_';

  Future<List<GameItem>> getGames() async {
    final prefs = await SharedPreferences.getInstance();
    final packages = prefs.getStringList(_kPackagesKey) ?? const [];
    return packages.map((pkg) {
      final millis = prefs.getInt('$_kLastPlayedPrefix$pkg');
      return GameItem(
        packageName: pkg,
        lastPlayed: millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null,
      );
    }).toList();
  }

  Future<void> addGame(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kPackagesKey) ?? [];
    if (!current.contains(packageName)) {
      current.add(packageName);
      await prefs.setStringList(_kPackagesKey, current);
    }
  }

  Future<void> removeGame(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kPackagesKey) ?? [];
    current.remove(packageName);
    await prefs.setStringList(_kPackagesKey, current);
    await prefs.remove('$_kLastPlayedPrefix$packageName');
  }

  Future<void> markPlayedNow(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_kLastPlayedPrefix$packageName',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
