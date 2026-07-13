import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AxialStride · Step Counter'),
        backgroundColor: scheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Step count ---
              Column(
                children: [
                  Text('STEPS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: 4,
                            color: scheme.outline,
                          )),
                  Text(
                    '$_steps',
                    style:
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [],
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Live signal chart ---
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processed acceleration (gravity removed)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const _Legend(),
                        const SizedBox(height: 4),
                        Expanded(child: SignalChart(samples: _samples.toList())),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // --- Sensitivity ---
              Row(
                children: [
                  const Text('Sensitivity'),
                  Expanded(
                    child: Slider(
                      value: _sensitivity,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: _sensitivity.toStringAsFixed(2),
                      onChanged: (v) {
                        setState(() {
                          _sensitivity = v;
                          _detector.sensitivity = v;
                        });
                      },
                    ),
                  ),
                ],
              ),

              // --- Controls ---
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleRunning,
                      icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      label: Text(_running ? 'Pause' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Assumptions ---
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: scheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uses acceleration magnitude, so it works in any '
                        'orientation — no assumption about how you hold the '
                        'phone. Adaptive threshold + refractory timing reject '
                        'spurious motion like hand wringing. Press Start and '
                        'walk with the phone.',
                        style: Theme.of(context).textTheme.bodySmall,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 3, color: c),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 14,
        children: [
          item(Theme.of(context).colorScheme.primary, 'signal'),
          item(Colors.orange, 'threshold'),
          item(Colors.redAccent, 'step'),
        ],
      ),
    );
  }
}
