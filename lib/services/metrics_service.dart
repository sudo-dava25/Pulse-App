import 'dart:async';
import 'dart:math';

import '../models/metrics.dart';
import 'root_shell.dart';

class MetricsService {
  MetricsService();

  static const _markStat = '__STAT__';
  static const _markProc = '__PROC__';
  static const _markGpuBusy = '__GPUBUSY__';
  static const _markGpuFreq = '__GPUFREQ__';
  static const _markTherm = '__THERM__';
  static const _markBattery = '__BATTERY__';
  static const _markFps = '__FPS__';
  static const _allMarks = {
    _markStat, _markProc, _markGpuBusy, _markGpuFreq, _markTherm, _markBattery, _markFps,
  };

  Timer? _timer;
  final _controller = StreamController<Metrics>.broadcast();
  Stream<Metrics> get stream => _controller.stream;

  String? _targetPackage;
  int? _targetPid;

  final List<double> _fpsHistory = [];
  final List<int> _vsyncHistoryNs = [];

  int? _lastProcJiffies;
  int? _lastTotalJiffies;
  int _coreCount = 8;

  DateTime? _lastBatterySampleTime;
  double? _lastBatteryLevel;

  bool get isRunning => _timer != null;

  Future<void> start({String? targetPackage}) async {
    stop();
    _targetPackage = targetPackage;
    _fpsHistory.clear();
    _vsyncHistoryNs.clear();
    _lastProcJiffies = null;
    _lastTotalJiffies = null;
    _targetPid = null;

    _coreCount = await _detectCoreCount();
    if (targetPackage != null) {
      _targetPid = await _resolvePid(targetPackage);
    }

    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _tick());
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _tick() async {
    final raw = await RootShell.exec(_buildCombinedCommand());
    final sections = _splitSections(raw);

    final fpsResult = _targetPackage != null
        ? _parseFps(sections[_markFps] ?? '')
        : (instant: 0.0, avg: 0.0, low1: 0.0);
    final cpu = _parseCpu(sections[_markStat] ?? '', sections[_markProc] ?? '');
    final gpu = _parseGpuBusy(sections[_markGpuBusy] ?? '');
    final gpuFreq = _parseGpuFreq(sections[_markGpuFreq] ?? '');
    final temps = _parseTemps(sections[_markTherm] ?? '');
    final battery = _parseBattery(sections[_markBattery] ?? '');

    _controller.add(Metrics(
      fps: fpsResult.instant,
      avgFps: fpsResult.avg,
      low1PercentFps: fpsResult.low1,
      cpuPercent: cpu.total,
      corePercents: cpu.perCore,
      gpuPercent: gpu,
      gpuFreqMhz: gpuFreq,
      cpuTempC: temps.cpu,
      gpuTempC: temps.gpu,
      batteryTempC: battery.tempC,
      batteryDrainPerMinute: battery.drainPerMinute,
    ));
  }

  String _buildCombinedCommand() {
    final pkg = _targetPackage;
    final pid = _targetPid;
    final buffer = StringBuffer();

    buffer.writeln('echo $_markStat');
    buffer.writeln('cat /proc/stat');

    buffer.writeln('echo $_markProc');
    if (pid != null) {
      buffer.writeln('cat /proc/$pid/stat 2>/dev/null');
    }

    buffer.writeln('echo $_markGpuBusy');
    buffer.writeln('cat /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null');

    buffer.writeln('echo $_markGpuFreq');
    buffer.writeln('cat /sys/class/kgsl/kgsl-3d0/clock_mhz 2>/dev/null');

    buffer.writeln('echo $_markTherm');
    buffer.writeln(
      'for z in /sys/class/thermal/thermal_zone*; do echo "\$z:\$(cat \$z/type 2>/dev/null):\$(cat \$z/temp 2>/dev/null)"; done',
    );

    buffer.writeln('echo $_markBattery');
    buffer.writeln('dumpsys battery');

    if (pkg != null) {
      buffer.writeln('echo $_markFps');
      buffer.writeln('dumpsys gfxinfo $pkg framestats');
    }

    return buffer.toString();
  }

  Map<String, String> _splitSections(String raw) {
    final result = <String, String>{};
    String? current;
    final buf = StringBuffer();

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (_allMarks.contains(trimmed)) {
        if (current != null) result[current] = buf.toString();
        current = trimmed;
        buf.clear();
      } else if (current != null) {
        buf.writeln(line);
      }
    }
    if (current != null) result[current] = buf.toString();
    return result;
  }

  Future<int> _detectCoreCount() async {
    final raw = await RootShell.exec('cat /proc/stat | grep -c "^cpu[0-9]"');
    final n = int.tryParse(raw.trim());
    return (n != null && n > 0) ? n : 8;
  }

  Future<int?> _resolvePid(String pkg) async {
    final raw = await RootShell.exec('pidof $pkg');
    final first = raw.trim().split(RegExp(r'\s+')).firstOrNull;
    return first == null ? null : int.tryParse(first);
  }

  ({double instant, double avg, double low1}) _parseFps(String raw) {
    if (raw.isEmpty) return (instant: 0.0, avg: 0.0, low1: 0.0);

    final lines = raw.split('\n');
    var inTable = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('---PROFILEDATA---')) {
        inTable = true;
        continue;
      }
      if (!inTable) continue;
      if (trimmed.isEmpty || trimmed.startsWith('Flags')) continue;

      final cols = trimmed.split(',');
     
      if (cols.length < 2) continue;
      final vsync = int.tryParse(cols[1].trim());
      if (vsync == null || vsync == 0) continue;
      if (_vsyncHistoryNs.isEmpty || vsync != _vsyncHistoryNs.last) {
        _vsyncHistoryNs.add(vsync);
      }
    }

    if (_vsyncHistoryNs.length > 120) {
      _vsyncHistoryNs.removeRange(0, _vsyncHistoryNs.length - 120);
    }
    if (_vsyncHistoryNs.length < 2) return (instant: 0.0, avg: 0.0, low1: 0.0);

    final deltas = <double>[];
    for (var i = 1; i < _vsyncHistoryNs.length; i++) {
      final d = _vsyncHistoryNs[i] - _vsyncHistoryNs[i - 1];
      if (d > 0) deltas.add(1e9 / d);
    }
    if (deltas.isEmpty) return (instant: 0.0, avg: 0.0, low1: 0.0);

    final instant = deltas.last;
    _fpsHistory.add(instant);
    if (_fpsHistory.length > 60) _fpsHistory.removeAt(0);

    final avg = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
    final sorted = [..._fpsHistory]..sort();
    final low1Count = max(1, (sorted.length * 0.01).ceil());
    final low1 = sorted.take(low1Count).reduce((a, b) => a + b) / low1Count;

    return (instant: instant, avg: avg, low1: low1);
  }

  ({double total, List<double> perCore}) _parseCpu(String statRaw, String procRaw) {
    final firstLine = statRaw.split('\n').firstWhere(
          (l) => l.startsWith('cpu '),
          orElse: () => '',
        );
    if (firstLine.isEmpty) return (total: 0.0, perCore: const <double>[]);

    final parts = firstLine.trim().split(RegExp(r'\s+')).skip(1);
    final values = parts.map((e) => int.tryParse(e) ?? 0).toList();
    final totalJiffies = values.fold<int>(0, (a, b) => a + b);

    double totalPercent = 0;
    if (_targetPid != null && procRaw.trim().isNotEmpty) {
     
      final closeParen = procRaw.lastIndexOf(')');
      if (closeParen != -1) {
        final afterName = procRaw.substring(closeParen + 1).trim();
        final procFields = afterName.split(RegExp(r'\s+'));
       
        if (procFields.length >= 13) {
          final utime = int.tryParse(procFields[11]) ?? 0;
          final stime = int.tryParse(procFields[12]) ?? 0;
          final procJiffies = utime + stime;

          if (_lastProcJiffies != null && _lastTotalJiffies != null) {
            final dProc = procJiffies - _lastProcJiffies!;
            final dTotal = totalJiffies - _lastTotalJiffies!;
            if (dTotal > 0) {
              totalPercent = (dProc / dTotal) * _coreCount * 100.0;
              totalPercent = totalPercent.clamp(0, 100 * _coreCount).toDouble();
            }
          }
          _lastProcJiffies = procJiffies;
        }
      }
    }
    _lastTotalJiffies = totalJiffies;

    final perCoreLines =
        statRaw.split('\n').where((l) => RegExp(r'^cpu[0-9]+ ').hasMatch(l)).toList();
    final perCore = <double>[];
    for (final line in perCoreLines) {
      final f = line.trim().split(RegExp(r'\s+')).skip(1).map((e) => int.tryParse(e) ?? 0).toList();
      if (f.length < 4) continue;
      final idle = f[3];
      final total = f.fold<int>(0, (a, b) => a + b);
      if (total > 0) {
        perCore.add(((total - idle) / total * 100).clamp(0, 100));
      }
    }

    return (total: totalPercent, perCore: perCore);
  }

  double? _parseGpuBusy(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final busy = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (busy == null || total == null || total == 0) return null;
    return (busy / total * 100).clamp(0, 100).toDouble();
  }

  double? _parseGpuFreq(String raw) {
    return double.tryParse(raw.trim());
  }

  ({double? cpu, double? gpu}) _parseTemps(String raw) {
    double? cpuTemp;
    double? gpuTemp;
    for (final line in raw.split('\n')) {
      final segs = line.split(':');
      if (segs.length < 3) continue;
      final type = segs[1].toLowerCase();
      final rawTemp = double.tryParse(segs[2].trim());
      if (rawTemp == null) continue;
     
      final celsius = rawTemp > 200 ? rawTemp / 1000.0 : rawTemp;
      if (cpuTemp == null && (type.contains('cpu') || type.contains('soc') || type.contains('big'))) {
        cpuTemp = celsius;
      }
      if (gpuTemp == null && type.contains('gpu')) {
        gpuTemp = celsius;
      }
    }
    return (cpu: cpuTemp, gpu: gpuTemp);
  }

  ({double? tempC, double? drainPerMinute}) _parseBattery(String raw) {
    double? tempC;
    double? level;
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.startsWith('temperature:')) {
        final v = int.tryParse(t.split(':').last.trim());
        if (v != null) tempC = v / 10.0;
      } else if (t.startsWith('level:')) {
        level = double.tryParse(t.split(':').last.trim());
      }
    }

    double? drain;
    final now = DateTime.now();
    if (_lastBatterySampleTime != null && _lastBatteryLevel != null && level != null) {
      final minutes = now.difference(_lastBatterySampleTime!).inSeconds / 60.0;
      if (minutes > 0) {
        drain = (_lastBatteryLevel! - level) / minutes;
      }
    }
    _lastBatterySampleTime = now;
    if (level != null) _lastBatteryLevel = level;

    return (tempC: tempC, drainPerMinute: drain);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
