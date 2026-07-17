import 'dart:async';

import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../models/overlay_theme.dart';
import '../services/metrics_service.dart';
import '../theme/app_colors.dart';
import '../widgets/overlay_widget_view.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({
    super.key,
    required this.selectedTheme,
    required this.onSelected,
    required this.metricsService,
  });

  final OverlayThemeData selectedTheme;
  final ValueChanged<OverlayThemeData> onSelected;
  final MetricsService metricsService;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  Metrics _metrics = Metrics.zero();
  bool _expanded = false;
  StreamSubscription<Metrics>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.metricsService.stream.listen((m) {
      if (mounted) setState(() => _metrics = m);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        const Text('Kustomisasi Overlay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Text('Pilih tema tampilan overlay saat main game',
            style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Container(
          height: 150,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B3140), Color(0xFF161A22)],
            ),
          ),
          child: OverlayWidgetView(metrics: _metrics, theme: widget.selectedTheme, expanded: _expanded),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(_expanded ? 'Lihat Mode Ringkas' : 'Lihat Mode Luas',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kOverlayThemes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, i) {
            final t = kOverlayThemes[i];
            final selected = t.id == widget.selectedTheme.id;
            return GestureDetector(
              onTap: () => widget.onSelected(t),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppColors.blue : Colors.transparent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: t.swatchGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                            ),
                          ),
                          if (selected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(t.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
