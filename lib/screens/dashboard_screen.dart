import 'dart:async';

import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../services/metrics_service.dart';
import '../services/overlay_controller.dart';
import '../services/root_shell.dart';
import '../theme/app_colors.dart';
import '../widgets/metric_card.dart';
import '../widgets/waveform_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.metricsService,
    required this.overlayController,
  });

  final MetricsService metricsService;
  final OverlayController overlayController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<double> _fpsHistory = [];
  Metrics _latest = Metrics.zero();
  bool? _rootAvailable;
  StreamSubscription<Metrics>? _sub;

  @override
  void initState() {
    super.initState();
    RootShell.isRootAvailable().then((v) {
      if (mounted) setState(() => _rootAvailable = v);
    });
    _sub = widget.metricsService.stream.listen((m) {
      if (!mounted) return;
      setState(() {
        _latest = m;
        _fpsHistory.add(m.fps);
        if (_fpsHistory.length > 60) _fpsHistory.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionActive = widget.overlayController.isSessionActive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        _buildHeroCard(),
        const SizedBox(height: 12),
        _buildSessionRow(sessionActive),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.memory_rounded,
                iconBg: AppColors.orangeSoft,
                iconColor: AppColors.orange,
                label: 'CPU',
                value: '${_latest.cpuPercent.round()}%',
                child: _buildCoreBars(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                icon: Icons.blur_on_rounded,
                iconBg: AppColors.purpleSoft,
                iconColor: AppColors.purple,
                label: 'GPU',
                value: _latest.gpuPercent != null ? '${_latest.gpuPercent!.round()}%' : '-',
                subLabel: _latest.gpuFreqMhz != null
                    ? 'busy · ${_latest.gpuFreqMhz!.round()}MHz'
                    : 'tidak tersedia di device ini',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildThermalCard(),
      ],
    );
  }

  Widget _buildHeader() {
    final rootKnown = _rootAvailable != null;
    final rootOk = _rootAvailable == true;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pulse', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text('Root telemetry', style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        if (rootKnown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: rootOk ? AppColors.greenSoft : AppColors.pinkSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: rootOk ? AppColors.green : AppColors.pink, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  rootOk ? 'Root Aktif' : 'Root Tidak Terdeteksi',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: rootOk ? AppColors.green : AppColors.pink),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FPS Sekarang', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_latest.fps.round()}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.blue, height: 1)),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text('fps', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('rata-rata ${_latest.avgFps.round()}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
                  Text('1% low ${_latest.low1PercentFps.round()}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          WaveformChart(values: _fpsHistory, color: AppColors.blue),
        ],
      ),
    );
  }

  Widget _buildSessionRow(bool active) {
    final pkg = widget.overlayController.activePackage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.blue, Color(0xFF5AC8FA)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? (pkg ?? 'Sesi aktif') : 'Belum ada sesi berjalan',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  active ? 'Overlay sedang tampil' : 'Pilih game di tab Game untuk mulai',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(20)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildCoreBars() {
    final cores = _latest.corePercents;
    if (cores.isEmpty) return const SizedBox(height: 22);
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in cores)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 3),
                height: (v.clamp(0, 100) / 100) * 22,
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThermalCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.local_fire_department_rounded, size: 13, color: AppColors.pink),
              ),
              const SizedBox(width: 7),
              const Text('Termal & Baterai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 9),
          _thermRow('CPU', _latest.cpuTempC != null ? '${_latest.cpuTempC!.round()}°C' : '-', AppColors.orange),
          const SizedBox(height: 8),
          _thermRow('GPU', _latest.gpuTempC != null ? '${_latest.gpuTempC!.round()}°C' : '-', AppColors.purple),
          const SizedBox(height: 8),
          _thermRow(
            'Baterai',
            _latest.batteryTempC != null
                ? '${_latest.batteryTempC!.round()}°C'
                    '${_latest.batteryDrainPerMinute != null ? ' · ${_latest.batteryDrainPerMinute!.toStringAsFixed(1)}%/mnt' : ''}'
                : '-',
            AppColors.green,
          ),
        ],
      ),
    );
  }

  Widget _thermRow(String label, String value, Color dot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
