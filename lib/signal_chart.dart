import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'step_detector.dart';

/// A lightweight real-time line chart of the processed acceleration signal,
/// the adaptive threshold, and markers where steps were detected.
class SignalChart extends StatelessWidget {
  const SignalChart({super.key, required this.samples});

  final List<ProcessedSample> samples;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SignalPainter(
        samples: samples,
        signalColor: scheme.primary,
        thresholdColor: scheme.outline,
        stepColor: AppColors.marker,
        gridColor: scheme.outline.withValues(alpha: 0.5),
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

    // Zero line, kept faint — a quiet reference rather than a strong grid.
    final zeroPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, yFor(0)), Offset(size.width, yFor(0)), zeroPaint);

    if (samples.length < 2) return;

    // Adaptive threshold (upper and mirrored lower band) — dashed, muted.
    final threshPaint = Paint()
      ..color = thresholdColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, threshPaint, samples, xFor,
        (s) => yFor(s.threshold));
    _drawDashedPath(canvas, threshPaint, samples, xFor,
        (s) => yFor(-s.threshold));

    // Signal trace — the one line drawn in full accent weight.
    final signalPaint = Paint()
      ..color = signalColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
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

    // Step markers — small ring rather than a filled dot, quieter on screen.
    final markerFill = Paint()..color = stepColor;
    final markerRing = Paint()
      ..color = stepColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].isStep) {
        final center = Offset(xFor(i), yFor(samples[i].net));
        canvas.drawCircle(center, 3, markerFill);
        canvas.drawCircle(center, 6, markerRing);
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Paint paint,
    List<ProcessedSample> samples,
    double Function(int) xFor,
    double Function(ProcessedSample) yFor, {
    double dashLength = 5,
    double gapLength = 4,
  }) {
    double drawn = 0;
    bool dashOn = true;
    Offset? prev;
    for (int i = 0; i < samples.length; i++) {
      final cur = Offset(xFor(i), yFor(samples[i]));
      if (prev != null) {
        final segment = (cur - prev).distance;
        double consumed = 0;
        while (consumed < segment) {
          final remaining = (dashOn ? dashLength : gapLength) - drawn;
          final step = math.min(remaining, segment - consumed);
          final t0 = consumed / segment;
          final t1 = (consumed + step) / segment;
          final p0 = Offset.lerp(prev, cur, t0)!;
          final p1 = Offset.lerp(prev, cur, t1)!;
          if (dashOn) {
            canvas.drawLine(p0, p1, paint);
          }
          consumed += step;
          drawn += step;
          if (drawn >= (dashOn ? dashLength : gapLength)) {
            drawn = 0;
            dashOn = !dashOn;
          }
        }
      }
      prev = cur;
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter old) => true;
}