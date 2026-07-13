import 'dart:collection';
import 'dart:math' as math;

/// One processed accelerometer sample, kept for the live chart.
class ProcessedSample {
  ProcessedSample({
    required this.time,
    required this.net,
    required this.threshold,
    required this.isStep,
  });

  /// Seconds since the detector started.
  final double time;

  /// Gravity-removed, smoothed acceleration magnitude (oscillates around 0).
  final double net;

  /// Current adaptive detection threshold (the value `net` must exceed).
  final double threshold;

  /// True on the exact sample where a step was registered.
  final bool isStep;
}

/// Orientation-independent step detector.
///
/// Pipeline:
///   1. magnitude  m = sqrt(x^2 + y^2 + z^2)   -> independent of how the
///      phone is held, so we make no orientation assumption.
///   2. gravity removal via a slow exponential moving average (EMA) baseline
///      -> net = m - gravity, oscillating around 0 while walking.
///   3. light EMA smoothing to suppress high-frequency jitter.
///   4. peak detection on the smoothed signal using an *adaptive* threshold
///      (mean + k*std over a sliding window) with hysteresis and a refractory
///      period. These three guards are what make it robust to spurious motion
///      such as hand wringing.
class StepDetector {
  StepDetector({
    this.gravityAlpha = 0.8,
    this.smoothingAlpha = 0.4,
    this.windowSize = 50,
    this.thresholdFactor = 1.2,
    this.sensitivity = 1.0,
    this.minThreshold = 0.7,
    this.minStepInterval = const Duration(milliseconds: 250),
    this.maxStepInterval = const Duration(milliseconds: 2000),
  });

  /// EMA weight for the gravity baseline (closer to 1 = slower to adapt).
  final double gravityAlpha;

  /// EMA weight for signal smoothing (closer to 1 = smoother/laggier).
  final double smoothingAlpha;

  /// Number of recent samples used for the adaptive threshold statistics.
  final int windowSize;

  /// Std-deviation multiplier for the adaptive threshold.
  final double thresholdFactor;

  /// User-facing sensitivity. >1 counts more easily, <1 requires stronger
  /// motion. Scales the effective threshold inversely.
  double sensitivity;

  /// Floor for the adaptive threshold (m/s^2) so noise at rest never counts.
  final double minThreshold;

  /// Refractory period — fastest believable cadence (~4 steps/second).
  final Duration minStepInterval;

  /// If no step for this long, the cadence lock is considered broken (used to
  /// reset the "armed" state cleanly rather than to reject steps).
  final Duration maxStepInterval;

  // --- Running state ---------------------------------------------------------
  double? _gravity;
  double _smoothed = 0.0;
  final Queue<double> _window = Queue<double>();
  double _windowSum = 0.0;
  double _windowSumSq = 0.0;

  int _steps = 0;
  int? _startMicros;
  int? _lastStepMicros;

  // Peak-tracking state machine.
  bool _aboveThreshold = false;
  double _peakValue = 0.0;

  int get steps => _steps;

  double _currentThreshold = 0.0;
  double get currentThreshold => _currentThreshold;

  /// Feed one raw accelerometer reading (m/s^2, gravity included).
  /// Returns a [ProcessedSample] for display. [isStep] is true when this
  /// reading completed a step.
  ProcessedSample addReading(double x, double y, double z, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final micros = now.microsecondsSinceEpoch;
    _startMicros ??= micros;
    final t = (micros - _startMicros!) / 1e6;

    // 1. Orientation-independent magnitude.
    final mag = math.sqrt(x * x + y * y + z * z);

    // 2. Gravity removal (slow EMA baseline).
    _gravity = _gravity == null
        ? mag
        : gravityAlpha * _gravity! + (1 - gravityAlpha) * mag;
    final net = mag - _gravity!;

    // 3. Smoothing (fast EMA low-pass).
    _smoothed = smoothingAlpha * net + (1 - smoothingAlpha) * _smoothed;

    // 4a. Update sliding-window statistics on the smoothed signal.
    _pushWindow(_smoothed);
    final n = _window.length;
    final mean = _windowSum / n;
    final variance = math.max(0.0, _windowSumSq / n - mean * mean);
    final std = math.sqrt(variance);

    // Adaptive threshold, floored and scaled by user sensitivity.
    final adaptive = mean + thresholdFactor * std;
    _currentThreshold = math.max(minThreshold, adaptive) / sensitivity;

    // 4b. Peak detection with hysteresis + refractory period.
    final lower = _currentThreshold * 0.5;
    bool isStep = false;

    if (_smoothed > _currentThreshold) {
      // Inside a positive excursion — track its peak.
      _aboveThreshold = true;
      if (_smoothed > _peakValue) _peakValue = _smoothed;
    } else if (_smoothed < lower && _aboveThreshold) {
      // Excursion has ended (fell back below the hysteresis line). Register
      // one step for the excursion if the refractory period has passed.
      _aboveThreshold = false;
      _peakValue = 0.0;
      final okInterval = _lastStepMicros == null ||
          (micros - _lastStepMicros!) >= minStepInterval.inMicroseconds;
      if (okInterval) {
        _steps++;
        _lastStepMicros = micros;
        isStep = true;
      }
    }

    return ProcessedSample(
      time: t,
      net: _smoothed,
      threshold: _currentThreshold,
      isStep: isStep,
    );
  }

  void _pushWindow(double v) {
    _window.addLast(v);
    _windowSum += v;
    _windowSumSq += v * v;
    if (_window.length > windowSize) {
      final old = _window.removeFirst();
      _windowSum -= old;
      _windowSumSq -= old * old;
    }
  }

  /// Reset step count and all running state.
  void reset() {
    _gravity = null;
    _smoothed = 0.0;
    _window.clear();
    _windowSum = 0.0;
    _windowSumSq = 0.0;
    _steps = 0;
    _startMicros = null;
    _lastStepMicros = null;
    _aboveThreshold = false;
    _peakValue = 0.0;
    _currentThreshold = 0.0;
  }
}
