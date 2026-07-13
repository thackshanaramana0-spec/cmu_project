# AxialStride — Accelerometer Step Counter

A Flutter app that counts steps from raw accelerometer data, with a real-time
display of the processed signal. Runs on Android and iOS from a single codebase.

## Approach (short description)

**Goal:** count steps regardless of how the phone is held, and reject spurious
motion (e.g. hand wringing).

Signal-processing pipeline (`lib/step_detector.dart`), run on every
accelerometer sample (~50 Hz):

1. **Orientation independence — vector magnitude.**
   `m = sqrt(x² + y² + z²)`. Because we use the magnitude of the acceleration
   vector, the algorithm does not depend on device orientation, so *we make no
   assumption about how the phone is held.*

2. **Gravity removal (high-pass).** A slow exponential moving average (EMA)
   tracks the gravity baseline (~9.81 m/s²); subtracting it gives a `net`
   signal that oscillates around 0 while walking.

3. **Smoothing (low-pass).** A faster EMA suppresses high-frequency jitter.

4. **Peak detection with three robustness guards:**
   - **Adaptive threshold** = `mean + k·σ` over a sliding 1-second window,
     floored at a minimum so noise at rest never counts, and scaled by a
     user **sensitivity** slider.
   - **Hysteresis** — after the signal crosses the threshold, it must fall
     back below half the threshold before another step can be registered.
     This counts exactly one step per stride (one peak per excursion).
   - **Refractory period** — a minimum 250 ms between steps caps cadence at
     ~4 steps/s, rejecting fast tremor / hand-wringing bursts.

Peak detection was chosen (over zero-crossings) because a step's heel-strike
produces a clear, prominent peak in the magnitude signal, and prominence-based
thresholding is naturally robust to small spurious movements.

**Real-time display:** the app plots the processed acceleration, the live
adaptive threshold band, and a red dot at each detected step, plus the running
step count and a sensitivity control.

## Run it

```bash
flutter pub get
flutter run            # with an Android/iOS phone connected
```

Press **Start**, then walk with the phone. **Reset** zeroes the count. Adjust
**Sensitivity** if it over- or under-counts for your gait.

> The accelerometer only produces meaningful data on a physical phone; the
> desktop/web targets compile and show the UI but have no real sensor.

## Tests

```bash
flutter test
```

Includes a synthetic-walk test asserting the count lands within the 15% grading
tolerance, and a stationary-jitter test asserting near-zero false counts.

## Project layout

- `lib/step_detector.dart` — the signal processing + step-counting engine.
- `lib/signal_chart.dart` — real-time `CustomPainter` chart.
- `lib/main.dart` — UI: step count, chart, controls, assumptions note.
