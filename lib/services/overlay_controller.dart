import 'dart:async';

import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/overlay_theme.dart';
import 'foreground_watcher.dart';
import 'game_repository.dart';
import 'metrics_service.dart';

/// Mengatur satu "sesi main": mulai dari tap tombol Main di tab Game,
/// sampai overlay otomatis hilang saat user keluar dari game tersebut.
///
/// Alur (lihat juga penjelasan di README):
/// 1. [launchGame] set target package -> start [MetricsService] -> tampilkan
///    overlay -> baru lempar intent buka game-nya.
/// 2. Selagi overlay tampil, [_watchLoop] polling foreground app tiap 2 detik
///    sebagai jaring pengaman: begitu foreground BUKAN lagi target package,
///    sesi otomatis dihentikan.
/// 3. [stopSession] hentikan timer, metrics, dan tutup overlay.
class OverlayController {
  OverlayController({
    required this.metricsService,
    required this.gameRepository,
  });

  final MetricsService metricsService;
  final GameRepository gameRepository;

  Timer? _watchTimer;
  String? _activePackage;
  StreamSubscription<dynamic>? _metricsSub;
  OverlayThemeData _theme = kOverlayThemes.first;

  bool get isSessionActive => _activePackage != null;
  String? get activePackage => _activePackage;

  void setTheme(OverlayThemeData theme) {
    _theme = theme;
  }

  Future<bool> ensureOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    return await FlutterOverlayWindow.requestPermission();
  }

  /// Mulai sesi untuk [packageName]: metrics + overlay + buka game-nya.
  Future<void> launchGame(String packageName) async {
    if (isSessionActive) {
      await stopSession();
    }

    final hasPermission = await ensureOverlayPermission();
    if (!hasPermission) return;

    _activePackage = packageName;
    await gameRepository.markPlayedNow(packageName);

    await metricsService.start(targetPackage: packageName);
    _metricsSub = metricsService.stream.listen((metrics) {
      // Kirim data terbaru + tema aktif ke isolate overlay.
      FlutterOverlayWindow.shareData({
        'metrics': metrics.toMap(),
        'themeId': _theme.id,
      });
    });

    await FlutterOverlayWindow.showOverlay(
      height: 120,
      width: 220,
      alignment: OverlayAlignment.topLeft,
      enableDrag: true,
      overlayTitle: 'Pulse aktif',
      overlayContent: 'Memantau performa game',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
    );

    // Baru lempar intent buka game-nya SETELAH overlay siap, supaya
    // begitu game tampil di layar, overlay langsung ikut nongol.
    await InstalledApps.startApp(packageName);

    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkForeground());
  }

  Future<void> _checkForeground() async {
    if (_activePackage == null) return;
    final fg = await ForegroundWatcher.currentForegroundPackage();
    // fg null berarti tidak berhasil terdeteksi (misal root sempat gagal) -
    // jangan langsung dianggap "keluar game", tunggu sampel berikutnya.
    if (fg != null && fg != _activePackage) {
      await stopSession();
    }
  }

  Future<void> stopSession() async {
    _watchTimer?.cancel();
    _watchTimer = null;
    await _metricsSub?.cancel();
    _metricsSub = null;
    _activePackage = null;
    await FlutterOverlayWindow.closeOverlay();
    // Kembali ke polling sistem-wide (tanpa target) supaya Dashboard
    // tetap dapat data CPU/suhu/baterai walau tidak ada sesi game.
    await metricsService.start();
  }

  void dispose() {
    _watchTimer?.cancel();
    _metricsSub?.cancel();
    metricsService.dispose();
  }
}
