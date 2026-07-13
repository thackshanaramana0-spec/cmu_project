// Unit tests for the step-detection algorithm and a smoke test for the app.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:axialstride/main.dart';
import 'package:axialstride/step_detector.dart';

void main() {
  testWidgets('App shows a step counter starting at 0', (tester) async {
    await tester.pumpWidget(const AxialStrideApp());
    expect(find.text('STEPS'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  test('Detector counts a synthetic walking signal within 15% tolerance', () {
    final detector = StepDetector();
    const int trueSteps = 20;
    const double stepHz = 2.0; // 2 steps/second
    const int rate = 50; // 50 Hz sampling
    final start = DateTime(2020);

    final totalSamples = (trueSteps / stepHz * rate).round();
    for (int i = 0; i < totalSamples; i++) {
      final t = i / rate;
      // Gravity on z + a sharp periodic bump (heel-strike-like) plus noise.
      final phase = 2 * math.pi * stepHz * t;
      final s = math.sin(phase);
      final bump = 2.5 * (s > 0 ? s * s : 0);
      detector.addReading(
        0.2 * _noise(i),
        0.2 * _noise(i + 7),
        9.81 + bump,
        at: start.add(Duration(milliseconds: (t * 1000).round())),
      );
    }

    final err = (detector.steps - trueSteps).abs() / trueSteps;
    expect(err <= 0.15, isTrue,
        reason: 'counted ${detector.steps}, expected ~$trueSteps');
  });

  test('Detector ignores small stationary jitter', () {
    final detector = StepDetector();
    final start = DateTime(2020);
    for (int i = 0; i < 250; i++) {
      final t = i / 50.0;
      detector.addReading(
        0.15 * _noise(i),
        0.15 * _noise(i + 3),
        9.81 + 0.15 * _noise(i + 11),
        at: start.add(Duration(milliseconds: (t * 1000).round())),
      );
    }
    expect(detector.steps, lessThanOrEqualTo(2));
  });
}

/// A pseudo-random but deterministic value in roughly [-1, 1].
double _noise(int i) {
  final v = (i * 1103515245 + 12345) & 0x7fffffff;
  return (v % 1000) / 500.0 - 1.0;
}
