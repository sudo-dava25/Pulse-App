import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../models/overlay_theme.dart';

/// Tampilan bubble overlay, dipakai di DUA tempat:
/// 1. Layar "Kustomisasi Overlay" (preview statis/live di dalam app biasa).
/// 2. Isolate overlay asli ([overlayMain] di overlay_entry.dart).
///
/// Menjaga satu sumber kebenaran untuk visual overlay supaya preview di
/// dalam app selalu representatif dengan overlay yang benar-benar muncul
/// di atas game.
class OverlayWidgetView extends StatelessWidget {
  const OverlayWidgetView({
    super.key,
    required this.metrics,
    required this.theme,
    required this.expanded,
  });

  final Metrics metrics;
  final OverlayThemeData theme;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final content = expanded ? _buildExpanded() : _buildCompact();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: expanded
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          width: expanded ? 178 : null,
          decoration: BoxDecoration(
            color: theme.widgetBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.accentColor.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 13),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metrics.fps.round().toString(),
          style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(width: 4),
        Opacity(opacity: 0.65, child: Text('fps', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        _MiniBars(metrics: metrics, color: theme.accentColor),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              metrics.fps.round().toString(),
              style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.w800, fontSize: 28, height: 1),
            ),
            const SizedBox(width: 4),
            Opacity(opacity: 0.65, child: Text('fps', style: TextStyle(color: theme.textColor))),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Divider(height: 1, color: theme.textColor.withOpacity(0.15)),
        ),
        _statRow('CPU', '${metrics.cpuPercent.round()}%', const Color(0xFFFF9F0A)),
        const SizedBox(height: 7),
        _statRow('GPU', metrics.gpuPercent != null ? '${metrics.gpuPercent!.round()}%' : '-', const Color(0xFFBF5AF2)),
        const SizedBox(height: 7),
        _statRow('Suhu', metrics.cpuTempC != null ? '${metrics.cpuTempC!.round()}°C' : '-', const Color(0xFFFF375F)),
      ],
    );
  }

  Widget _statRow(String label, String value, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Opacity(opacity: 0.65, child: Text(label, style: TextStyle(color: theme.textColor, fontSize: 12))),
          ],
        ),
        Text(value, style: TextStyle(color: theme.textColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.metrics, required this.color});

  final Metrics metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cores = metrics.corePercents.isNotEmpty
        ? metrics.corePercents.take(5).toList()
        : List<double>.filled(5, 30);

    return SizedBox(
      height: 13,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in cores)
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: 2),
              height: 4 + (v.clamp(0, 100) / 100 * 9),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
            ),
        ],
      ),
    );
  }
}
