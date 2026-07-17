import 'dart:async';
import 'dart:math';

import '../models/metrics.dart';
import 'root_shell.dart';

/// Membaca & menghitung FPS/CPU/GPU/suhu secara berkala lewat root shell.
///
/// CATATAN JUJUR (baca sebelum ubah-ubah parsing di bawah):
/// - FPS per-game: diambil dari `dumpsys gfxinfo <pkg> framestats`, yang
///   mengembalikan tabel CSV berisi timestamp nanodetik tiap frame yang
///   dirender proses itu. Kolom persis bisa berbeda antar versi Android,
///   jadi parser di bawah mencari header "FRAMESTATS" lalu ambil kolom
///   VSYNC (index ke-2) secara defensif.
/// - CPU per-app: dihitung dari delta `/proc/<pid>/stat` (utime+stime)
///   dibagi delta `/proc/stat` total, dikali jumlah core. Butuh dua
///   sample berurutan, sample pertama akan menghasilkan 0.
/// - GPU: HANYA sistem-wide, tidak per-app - Android/vendor Adreno tidak
///   memecah GPU busy% per proses. Path sysfs `kgsl-3d0/gpubusy` spesifik
///   Qualcomm Adreno; di GPU lain (Mali/PowerVR) field ini akan null.
/// - Suhu: dibaca dari /sys/class/thermal/thermal_zone*, dicocokkan
///   berdasarkan nama zona yang mengandung "cpu"/"gpu" - penamaan zona
///   sangat bervariasi antar vendor, jadi anggap ini best-effort dan
///   perlu di-tuning per device saat testing nyata.
class MetricsService {
  MetricsService();

  Timer? _timer;
  final _controller = StreamController<Metrics>.broadcast();
  Stream<Metrics> get stream => _controller.stream;

  String? _targetPackage;
  int? _targetPid;

  final List<double> _fpsHistory = [];
  final List<int> _vsyncHistoryNs = [];

  int? _lastProcJiffies; // utime+stime proses target
  int? _lastTotalJiffies; // total dari /proc/stat
  int _coreCount = 8; // fallback, di-refresh saat start()

  DateTime? _lastBatterySampleTime;
  double? _lastBatteryLevel;

  bool get isRunning => _timer != null;

  /// Mulai polling. [targetPackage] null berarti hanya metrik
  /// sistem-wide (CPU total, suhu, baterai) yang diisi - dipakai saat
  /// belum ada game yang sedang dipantau.
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

    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
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
    final fpsResult = _targetPackage != null
        ? await _readFps(_targetPackage!)
        : (instant: 0.0, avg: 0.0, low1: 0.0);

    final cpu = await _readCpuPercent();
    final gpu = await _readGpuBusyPercent();
    final gpuFreq = await _readGpuFreqMhz();
    final temps = await _readTemps();
    final battery = await _readBattery();

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

  // ---------------------------------------------------------------------
  // FPS (per package, lewat framestats)
  // ---------------------------------------------------------------------

  Future<({double instant, double avg, double low1})> _readFps(String pkg) async {
    final raw = await RootShell.exec('dumpsys gfxinfo $pkg framestats');
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
      if (trimmed.startsWith('---PROFILEDATA---')) break;

      final cols = trimmed.split(',');
      // Kolom ke-2 (index 1) pada format framestats adalah VSYNC timestamp (ns).
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

  // ---------------------------------------------------------------------
  // CPU (per-app kalau ada target, selalu juga hitung total sistem)
  // ---------------------------------------------------------------------

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

  Future<({double total, List<double> perCore})> _readCpuPercent() async {
    // Total jiffies sistem, dari baris pertama /proc/stat.
    final statRaw = await RootShell.exec('cat /proc/stat');
    final firstLine = statRaw.split('\n').firstWhere(
          (l) => l.startsWith('cpu '),
          orElse: () => '',
        );
    if (firstLine.isEmpty) return (total: 0.0, perCore: const <double>[]);

    final parts = firstLine.trim().split(RegExp(r'\s+')).skip(1);
    final values = parts.map((e) => int.tryParse(e) ?? 0).toList();
    final totalJiffies = values.fold<int>(0, (a, b) => a + b);

    double totalPercent = 0;
    if (_targetPid != null) {
      final procRaw = await RootShell.exec('cat /proc/${_targetPid}/stat');
      // Field ke-2 (comm) dibungkus tanda kurung dan BISA mengandung spasi
      // (mis. nama proses custom ROM), jadi jangan split naif dari awal -
      // cari posisi ')' terakhir dulu, baru split sisanya.
      final closeParen = procRaw.lastIndexOf(')');
      if (closeParen != -1) {
        final afterName = procRaw.substring(closeParen + 1).trim();
        final procFields = afterName.split(RegExp(r'\s+'));
        // Setelah "pid (comm)", index 0 = state (field ke-3 asli),
        // sehingga utime ada di index 11, stime di index 12.
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

    // Estimasi beban per-core dari /proc/stat cpu0..N (untuk visual bar saja,
    // bukan cerminan proses target secara spesifik).
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

  // ---------------------------------------------------------------------
  // GPU (sistem-wide, best-effort - lihat catatan di kepala file)
  // ---------------------------------------------------------------------

  Future<double?> _readGpuBusyPercent() async {
    final raw = await RootShell.exec('cat /sys/class/kgsl/kgsl-3d0/gpubusy');
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final busy = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (busy == null || total == null || total == 0) return null;
    return (busy / total * 100).clamp(0, 100).toDouble();
  }

  Future<double?> _readGpuFreqMhz() async {
    final raw = await RootShell.exec('cat /sys/class/kgsl/kgsl-3d0/clock_mhz');
    final v = double.tryParse(raw.trim());
    return v;
  }

  // ---------------------------------------------------------------------
  // Suhu
  // ---------------------------------------------------------------------

  Future<({double? cpu, double? gpu})> _readTemps() async {
    final zoneList = await RootShell.exec(
      'for z in /sys/class/thermal/thermal_zone*; do echo "\$z:\$(cat \$z/type 2>/dev/null):\$(cat \$z/temp 2>/dev/null)"; done',
    );
    double? cpuTemp;
    double? gpuTemp;
    for (final line in zoneList.split('\n')) {
      final segs = line.split(':');
      if (segs.length < 3) continue;
      final type = segs[1].toLowerCase();
      final rawTemp = double.tryParse(segs[2].trim());
      if (rawTemp == null) continue;
      // Sebagian besar vendor melaporkan millidegree (perlu /1000),
      // sebagian lain sudah dalam derajat langsung - heuristik sederhana:
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

  Future<({double? tempC, double? drainPerMinute})> _readBattery() async {
    final raw = await RootShell.exec('dumpsys battery');
    double? tempC;
    double? level;
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.startsWith('temperature:')) {
        final v = int.tryParse(t.split(':').last.trim());
        if (v != null) tempC = v / 10.0; // dumpsys battery: persepuluh derajat
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
