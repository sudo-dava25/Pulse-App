import 'package:flutter/material.dart';

/// Grafik garis sederhana untuk riwayat FPS, gaya trace osiloskop tipis.
class WaveformChart extends StatelessWidget {
  const WaveformChart({
    super.key,
    required this.values,
    required this.color,
    this.minValue = 60,
    this.maxValue = 150,
    this.height = 54,
  });

  final List<double> values;
  final Color color;
  final double minValue;
  final double maxValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(values: values, color: color, minValue: minValue, maxValue: maxValue),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.values,
    required this.color,
    required this.minValue,
    required this.maxValue,
  });

  final List<double> values;
  final Color color;
  final double minValue;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final range = (maxValue - minValue).clamp(1, double.infinity);

    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = ((values[i] - minValue) / range).clamp(0.0, 1.0);
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
