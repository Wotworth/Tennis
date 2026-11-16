# Error budget: which error matters for which measurement

SYNTHETIC (2026-11-16T07:24:03Z). One synthetic singles session of 49 shots, reconstructed once per setting with ONE error source changed and the others at zero. Truth flown with the truth model (spin decay, changing lift, per-shot drag, gusts), so even the all-zero run is not perfect. Detector noise 0.3 px in every run except the detection sweep. Timing and air fixed at the truth plus the error (the session-wide refinement, which would absorb part of it, is off). Made by `vision/tools/errorBudget.m`.

| Source | Level | Shots found | Bounce, median / 90% (cm) | Net clearance, median / 90% (cm) | Speed, median / 90% (mph) | Speed within 2 mph | Spin effect, median / 90% (cm) | rpm, median (%) |
|---|---|---|---|---|---|---|---|---|
| sync | 0 ms | 94% | 0.5 / 0.9 | 0.1 / 0.2 | 1.46 / 2.27 | 85% | 12.3 / 30.3 | 16 |
| sync | 0.25 ms | 98% | 0.5 / 0.9 | 0.1 / 0.2 | 1.40 / 2.03 | 88% | 12.8 / 29.5 | 17 |
| sync | 0.5 ms | 94% | 0.6 / 1.3 | 0.1 / 0.3 | 1.36 / 2.69 | 83% | 11.5 / 33.7 | 18 |
| sync | 1 ms | 98% | 0.8 / 1.4 | 0.2 / 0.3 | 1.45 / 2.60 | 81% | 12.2 / 32.8 | 15 |
| sync | 2 ms | 98% | 1.3 / 2.2 | 0.4 / 0.6 | 1.43 / 3.09 | 79% | 16.9 / 32.4 | 16 |
| calibration | 0 px | 96% | 0.4 / 1.0 | 0.1 / 0.2 | 1.42 / 2.34 | 81% | 11.9 / 29.2 | 18 |
| calibration | 0.5 px | 94% | 0.7 / 1.1 | 0.3 / 0.4 | 1.42 / 2.86 | 76% | 11.3 / 32.5 | 18 |
| calibration | 1 px | 98% | 1.2 / 1.8 | 0.5 / 0.6 | 1.54 / 2.93 | 79% | 10.7 / 32.3 | 16 |
| calibration | 2 px | 98% | 2.0 / 2.7 | 0.3 / 0.5 | 1.53 / 2.84 | 71% | 19.8 / 38.6 | 17 |
| detection | 0 px | 98% | 0.5 / 1.0 | 0.0 / 0.2 | 1.44 / 2.57 | 85% | 12.7 / 31.3 | 19 |
| detection | 0.25 px | 98% | 0.4 / 0.8 | 0.1 / 0.2 | 1.42 / 2.56 | 88% | 13.7 / 31.9 | 20 |
| detection | 0.5 px | 96% | 0.6 / 1.2 | 0.1 / 0.2 | 1.40 / 2.38 | 83% | 11.8 / 26.3 | 19 |
| detection | 1 px | 98% | 0.9 / 2.5 | 0.1 / 0.3 | 1.47 / 3.07 | 79% | 15.5 / 34.8 | 18 |
| ball size | 3 px | 96% | 0.6 / 1.1 | 0.0 / 0.2 | 1.54 / 2.66 | 77% | 13.9 / 31.5 | 19 |
| ball size | 4 px | 98% | 0.5 / 1.1 | 0.1 / 0.2 | 1.50 / 2.39 | 81% | 10.4 / 28.7 | 17 |
| ball size | 5 px | 94% | 0.4 / 0.8 | 0.0 / 0.1 | 1.46 / 3.10 | 72% | 14.5 / 37.8 | 19 |
| ball size | 7 px | 100% | 0.4 / 0.8 | 0.1 / 0.2 | 1.45 / 3.10 | 82% | 16.4 / 31.8 | 21 |
| frame rate | 120 fps | 96% | 0.5 / 0.8 | 0.1 / 0.2 | 1.45 / 2.88 | 74% | 11.3 / 32.0 | 19 |
| frame rate | 240 fps | 94% | 0.4 / 0.7 | 0.1 / 0.2 | 0.66 / 1.57 | 98% | 6.8 / 17.2 | 22 |

**Which source dominates** (rise over the all-zero sync run, at a realistic level: sync 0.5 ms, calibration 1 px, detection 0.5 px, ball 3 px, 120 fps):

| Measurement | Dominant source | Rise | Then | Next |
|---|---|---|---|---|
| bounce position (median) | calibration | +0.72 cm | sync (+0.11) | ball size (+0.10) |
| net clearance (median) | calibration | +0.46 cm | sync (+0.06) | detection (+0.01) |
| speed (median) | ball size | +0.07 mph | calibration (+0.07) | frame rate (+-0.02) |
| spin effect (median) | ball size | +1.55 cm | detection (+-0.48) | sync (+-0.81) |

**Against the acceptance targets** (flagged where a setting breaks one):

- sync 0 ms: 94% of shots found, under AC-06 (95%).
- sync 0 ms: 85% of speeds within 2 mph, under AC-07 (90%).
- sync 0 ms: median spin-effect error 12.3 cm, over AC-10 (10 cm).
- sync 0 ms: median rpm error 16%, over AC-11 (10%).
- sync 0.25 ms: 88% of speeds within 2 mph, under AC-07 (90%).
- sync 0.25 ms: median spin-effect error 12.8 cm, over AC-10 (10 cm).
- sync 0.25 ms: median rpm error 17%, over AC-11 (10%).
- sync 0.5 ms: 94% of shots found, under AC-06 (95%).
- sync 0.5 ms: 83% of speeds within 2 mph, under AC-07 (90%).
- sync 0.5 ms: median spin-effect error 11.5 cm, over AC-10 (10 cm).
- sync 0.5 ms: median rpm error 18%, over AC-11 (10%).
- sync 1 ms: 81% of speeds within 2 mph, under AC-07 (90%).
- sync 1 ms: median spin-effect error 12.2 cm, over AC-10 (10 cm).
- sync 1 ms: median rpm error 15%, over AC-11 (10%).
- sync 1 ms: itself outside AC-05 (0.5 ms).
- sync 2 ms: 79% of speeds within 2 mph, under AC-07 (90%).
- sync 2 ms: median spin-effect error 16.9 cm, over AC-10 (10 cm).
- sync 2 ms: median rpm error 16%, over AC-11 (10%).
- sync 2 ms: itself outside AC-05 (0.5 ms).
- calibration 0 px: 81% of speeds within 2 mph, under AC-07 (90%).
- calibration 0 px: median spin-effect error 11.9 cm, over AC-10 (10 cm).
- calibration 0 px: median rpm error 18%, over AC-11 (10%).
- calibration 0.5 px: 94% of shots found, under AC-06 (95%).
- calibration 0.5 px: 76% of speeds within 2 mph, under AC-07 (90%).
- calibration 0.5 px: median spin-effect error 11.3 cm, over AC-10 (10 cm).
- calibration 0.5 px: median rpm error 18%, over AC-11 (10%).
- calibration 1 px: 79% of speeds within 2 mph, under AC-07 (90%).
- calibration 1 px: median spin-effect error 10.7 cm, over AC-10 (10 cm).
- calibration 1 px: median rpm error 16%, over AC-11 (10%).
- calibration 2 px: 71% of speeds within 2 mph, under AC-07 (90%).
- calibration 2 px: median spin-effect error 19.8 cm, over AC-10 (10 cm).
- calibration 2 px: median rpm error 17%, over AC-11 (10%).
- calibration 2 px: itself outside AC-04 (1 px).
- detection 0 px: 85% of speeds within 2 mph, under AC-07 (90%).
- detection 0 px: median spin-effect error 12.7 cm, over AC-10 (10 cm).
- detection 0 px: median rpm error 19%, over AC-11 (10%).
- detection 0.25 px: 88% of speeds within 2 mph, under AC-07 (90%).
- detection 0.25 px: median spin-effect error 13.7 cm, over AC-10 (10 cm).
- detection 0.25 px: median rpm error 20%, over AC-11 (10%).
- detection 0.5 px: 83% of speeds within 2 mph, under AC-07 (90%).
- detection 0.5 px: median spin-effect error 11.8 cm, over AC-10 (10 cm).
- detection 0.5 px: median rpm error 19%, over AC-11 (10%).
- detection 1 px: 79% of speeds within 2 mph, under AC-07 (90%).
- detection 1 px: median spin-effect error 15.5 cm, over AC-10 (10 cm).
- detection 1 px: median rpm error 18%, over AC-11 (10%).
- ball size 3 px: 77% of speeds within 2 mph, under AC-07 (90%).
- ball size 3 px: median spin-effect error 13.9 cm, over AC-10 (10 cm).
- ball size 3 px: median rpm error 19%, over AC-11 (10%).
- ball size 4 px: 81% of speeds within 2 mph, under AC-07 (90%).
- ball size 4 px: median spin-effect error 10.4 cm, over AC-10 (10 cm).
- ball size 4 px: median rpm error 17%, over AC-11 (10%).
- ball size 5 px: 94% of shots found, under AC-06 (95%).
- ball size 5 px: 72% of speeds within 2 mph, under AC-07 (90%).
- ball size 5 px: median spin-effect error 14.5 cm, over AC-10 (10 cm).
- ball size 5 px: median rpm error 19%, over AC-11 (10%).
- ball size 7 px: 82% of speeds within 2 mph, under AC-07 (90%).
- ball size 7 px: median spin-effect error 16.4 cm, over AC-10 (10 cm).
- ball size 7 px: median rpm error 21%, over AC-11 (10%).
- frame rate 120 fps: 74% of speeds within 2 mph, under AC-07 (90%).
- frame rate 120 fps: median spin-effect error 11.3 cm, over AC-10 (10 cm).
- frame rate 120 fps: median rpm error 19%, over AC-11 (10%).
- frame rate 240 fps: 94% of shots found, under AC-06 (95%).
- frame rate 240 fps: median rpm error 22%, over AC-11 (10%).
