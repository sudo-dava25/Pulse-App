import 'dart:async';

import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/overlay_theme.dart';
import 'foreground_watcher.dart';
import 'game_repository.dart';
import 'metrics_service.dart';

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
    final result = await FlutterOverlayWindow.requestPermission();
    return result ?? false;
  }

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

    await InstalledApps.startApp(packageName);

    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkForeground());
  }

  Future<void> _checkForeground() async {
    if (_activePackage == null) return;
    final fg = await ForegroundWatcher.currentForegroundPackage();
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
    await metricsService.start();
  }

  void dispose() {
    _watchTimer?.cancel();
    _metricsSub?.cancel();
    metricsService.dispose();
  }
}
