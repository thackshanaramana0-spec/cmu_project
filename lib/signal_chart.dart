import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'step_detector.dart';

/// A lightweight real-time line chart of the processed acceleration signal,
/// the adaptive threshold, and markers where steps were detected.
class SignalChart extends StatelessWidget {
  const SignalChart({super.key, required this.samples});

  final List<ProcessedSample> samples;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SignalPainter(
        samples: samples,
        signalColor: Theme.of(context).colorScheme.primary,
        thresholdColor: Colors.orange,
        stepColor: Colors.redAccent,
        gridColor: Theme.of(context).dividerColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SignalPainter extends CustomPainter {
  _SignalPainter({
    required this.samples,
    required this.signalColor,
    required this.thresholdColor,
    required this.stepColor,
    required this.gridColor,
  });

  final List<ProcessedSample> samples;
  final Color signalColor;
  final Color thresholdColor;
  final Color stepColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Vertical scale: fit the data with a sane minimum range.
    double maxAbs = 2.0;
    for (final s in samples) {
      maxAbs = math.max(maxAbs, s.net.abs());
      maxAbs = math.max(maxAbs, s.threshold.abs());
    }
    maxAbs *= 1.15;

    double yFor(double v) => size.height / 2 - (v / maxAbs) * (size.height / 2);
    double xFor(int i) =>
        samples.length <= 1 ? 0 : i / (samples.length - 1) * size.width;

    // Zero line.
    final zeroPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, yFor(0)), Offset(size.width, yFor(0)), zeroPaint);

    if (samples.length < 2) return;

    // Adaptive threshold (upper and mirrored lower band).
    final threshPaint = Paint()
      ..color = thresholdColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final upper = Path();
    final lower = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = xFor(i);
      final tu = yFor(samples[i].threshold);
      final tl = yFor(-samples[i].threshold);
      if (i == 0) {
        upper.moveTo(x, tu);
        lower.moveTo(x, tl);
      } else {
        upper.lineTo(x, tu);
        lower.lineTo(x, tl);
      }
    }
    canvas.drawPath(upper, threshPaint);
    canvas.drawPath(lower, threshPaint);

    // Signal trace.
    final signalPaint = Paint()
      ..color = signalColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = xFor(i);
      final y = yFor(samples[i].net);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, signalPaint);

    // Step markers.
    final stepPaint = Paint()..color = stepColor;
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].isStep) {
        canvas.drawCircle(
            Offset(xFor(i), yFor(samples[i].net)), 4, stepPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter old) => true;
}
