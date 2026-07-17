/// Snapshot satu kali pembacaan telemetry.
///
/// Semua nilai diisi lewat [MetricsService] dengan cara membaca /proc,
/// sysfs, dan output `dumpsys` lewat shell root. Field yang tidak
/// tersedia di device tertentu (misal GPU vendor selain Adreno) akan
/// bernilai null, bukan 0, supaya UI bisa menampilkan "-" alih-alih
/// angka palsu.
class Metrics {
  final double fps;
  final double avgFps;
  final double low1PercentFps;

  final double cpuPercent;
  final List<double> corePercents;

  final double? gpuPercent;
  final double? gpuFreqMhz;

  final double? cpuTempC;
  final double? gpuTempC;
  final double? batteryTempC;
  final double? batteryDrainPerMinute;

  const Metrics({
    required this.fps,
    required this.avgFps,
    required this.low1PercentFps,
    required this.cpuPercent,
    required this.corePercents,
    this.gpuPercent,
    this.gpuFreqMhz,
    this.cpuTempC,
    this.gpuTempC,
    this.batteryTempC,
    this.batteryDrainPerMinute,
  });

  factory Metrics.zero() => const Metrics(
        fps: 0,
        avgFps: 0,
        low1PercentFps: 0,
        cpuPercent: 0,
        corePercents: [],
      );

  /// Dipakai saat mengirim/menerima data lewat [FlutterOverlayWindow.shareData],
  /// yang hanya bisa membawa tipe primitif/Map sederhana.
  Map<String, dynamic> toMap() => {
        'fps': fps,
        'avgFps': avgFps,
        'low1PercentFps': low1PercentFps,
        'cpuPercent': cpuPercent,
        'corePercents': corePercents,
        'gpuPercent': gpuPercent,
        'gpuFreqMhz': gpuFreqMhz,
        'cpuTempC': cpuTempC,
        'gpuTempC': gpuTempC,
        'batteryTempC': batteryTempC,
        'batteryDrainPerMinute': batteryDrainPerMinute,
      };

  factory Metrics.fromMap(Map<dynamic, dynamic> map) => Metrics(
        fps: (map['fps'] as num?)?.toDouble() ?? 0,
        avgFps: (map['avgFps'] as num?)?.toDouble() ?? 0,
        low1PercentFps: (map['low1PercentFps'] as num?)?.toDouble() ?? 0,
        cpuPercent: (map['cpuPercent'] as num?)?.toDouble() ?? 0,
        corePercents: (map['corePercents'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        gpuPercent: (map['gpuPercent'] as num?)?.toDouble(),
        gpuFreqMhz: (map['gpuFreqMhz'] as num?)?.toDouble(),
        cpuTempC: (map['cpuTempC'] as num?)?.toDouble(),
        gpuTempC: (map['gpuTempC'] as num?)?.toDouble(),
        batteryTempC: (map['batteryTempC'] as num?)?.toDouble(),
        batteryDrainPerMinute: (map['batteryDrainPerMinute'] as num?)?.toDouble(),
      );
}
