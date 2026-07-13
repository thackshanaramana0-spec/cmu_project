import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'app_theme.dart';
import 'signal_chart.dart';
import 'step_detector.dart';

void main() {
  runApp(const AxialStrideApp());
}

class AxialStrideApp extends StatelessWidget {
  const AxialStrideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AxialStride',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const StepCounterPage(),
    );
  }
}

class StepCounterPage extends StatefulWidget {
  const StepCounterPage({super.key});

  @override
  State<StepCounterPage> createState() => _StepCounterPageState();
}

class _StepCounterPageState extends State<StepCounterPage> {
  final StepDetector _detector = StepDetector();

  /// Ring buffer of recent processed samples for the live chart (~5s @ 50Hz).
  final Queue<ProcessedSample> _samples = Queue<ProcessedSample>();
  static const int _maxSamples = 250;

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _running = false;
  int _steps = 0;
  double _sensitivity = 1.0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _toggleRunning() {
    if (_running) {
      _sub?.cancel();
      _sub = null;
      setState(() => _running = false);
    } else {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval, // ~50 Hz
      ).listen(_onReading);
      setState(() => _running = true);
    }
  }

  void _onReading(AccelerometerEvent e) {
    final sample = _detector.addReading(e.x, e.y, e.z);
    _samples.addLast(sample);
    while (_samples.length > _maxSamples) {
      _samples.removeFirst();
    }
    setState(() => _steps = _detector.steps);
  }

  void _reset() {
    _detector.reset();
    _samples.clear();
    setState(() => _steps = 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AXIALSTRIDE'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _StatusPill(running: _running),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Step count ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text('STEPS', style: textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text('$_steps', style: textTheme.displayLarge),
                  ],
                ),
              ),

              // --- Live signal chart ---
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ACCELERATION',
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 11,
                                letterSpacing: 2,
                              ),
                            ),
                            const _Legend(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SignalChart(samples: _samples.toList()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Sensitivity ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SENSITIVITY', style: textTheme.labelLarge),
                  Text(
                    _sensitivity.toStringAsFixed(2),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: Theme.of(context).sliderTheme.copyWith(
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                child: Slider(
                  value: _sensitivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: (v) {
                    setState(() {
                      _sensitivity = v;
                      _detector.sensitivity = v;
                    });
                  },
                ),
              ),
              const SizedBox(height: 4),

              // --- Controls ---
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleRunning,
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: scheme.onPrimary,
                      ),
                      label: Text(_running ? 'Pause' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // --- Assumptions ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: scheme.outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Uses acceleration magnitude, so it works in any '
                        'orientation. Adaptive threshold and refractory '
                        'timing reject spurious motion like hand wringing. '
                        'Press Start and walk with the phone.',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = running ? scheme.primary : scheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            running ? 'LIVE' : 'IDLE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: running ? scheme.primary : scheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
    return Wrap(
      spacing: 12,
      children: [
        item(scheme.primary, 'signal'),
        item(scheme.outline, 'threshold'),
        item(AppColors.marker, 'step'),
      ],
    );
  }
}