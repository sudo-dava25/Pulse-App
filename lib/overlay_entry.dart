import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'models/metrics.dart';
import 'models/overlay_theme.dart';
import 'widgets/overlay_widget_view.dart';

/// PENTING: fungsi ini adalah entry point terpisah yang dijalankan
/// engine Flutter KEDUA (isolate overlay), bukan bagian dari widget
/// tree app utama. Anotasi `vm:entry-point` wajib ada supaya tidak
/// di-tree-shake saat build release - lihat dokumentasi
/// flutter_overlay_window.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  Metrics _metrics = Metrics.zero();
  OverlayThemeData _theme = kOverlayThemes.first;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        final metricsMap = event['metrics'];
        final themeId = event['themeId'];
        setState(() {
          if (metricsMap is Map) _metrics = Metrics.fromMap(metricsMap);
          if (themeId is String) _theme = themeById(themeId);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Align(
            alignment: Alignment.topLeft,
            child: OverlayWidgetView(
              metrics: _metrics,
              theme: _theme,
              expanded: _expanded,
            ),
          ),
        ),
      ),
    );
  }
}
