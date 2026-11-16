# Tennis Vision, built ahead of the hardware (15 Nov)

Chris's order of 15 Nov, built without cameras or the PC. Everything is tested on GitHub on every push: MATLAB (MathWorks' action), the Worker's tests, and the app's unit and screenshot tests. Nothing has run on the closet PC or a GoPro. Every number tuned on synthetic data is listed in [VISION-RETUNE.md](../VISION-RETUNE.md).

| # | Step | State | Tested by |
|---|---|---|---|
| 1 | Placement check and fence lookup table ([TV-PH-0a](TV-PH-0a.md)) | done; provisional lens figures | MATLAB CI |
| 2 | Physics core: flight model, RK4 vs ode45, air density, court | done | MATLAB CI |
| 3 | Synthetic footage generator (TV-TST-01), and a data-level generator for long sessions | done | MATLAB CI |
| 4 | Pipeline end to end on synthetic footage | all checks pass; results below | MATLAB CI (`pipelineTest`, 67 of 67 checks across all test files) |
| 5 | Card import, GoPro telemetry, pairing, courts by GPS, watcher | done | MATLAB CI (fake cards, GoPro's HERO8 sample) |
| 6 | Cloudflare Worker, D1 schema, R2 (not deployed) | done | Worker CI (18 tests) |
| 7 | App vision screens, courts, trends, "which one is you?", Ball check, opponents | done, with a synthetic sample; release v0.6.19 | app CI (139 tests) |
| 8 | PC setup script | written, not run, not syntax-checked | none |

## Step 4: the pipeline against the synthetic truth

On a 26-second, two-camera synthetic session at a quarter of 4K resolution (two rallies, a changeover, an out ball, a net ball):

| Check | Target | Result |
|---|---|---|
| Camera position (pose from the court lines, no layout assumed) | - | 1.0 cm and 0.6 cm; angle 0.04° and 0.03° |
| Camera timing (AC-05) | under 0.5 ms | 0.20 ms |
| Every shot inside a found rally (AC-03) | all | all |
| Shots reconstructed (AC-06) | 95% | 9 of 9 |
| No phantom hits | none | none |
| Speed within 2 mph (AC-07) | 90% of shots | met (the log shows the first six: worst 0.9 mph) |
| Bounce position (AC-08) | median under 5 cm | median 1.1 cm; worst 11 cm |
| Spin effect (AC-10, at a quarter of 4K) | median under 10 cm | median 4.6 cm; worst 30 cm |
| Hitter, through the changeover (AC-13) | 99% | 9 of 9 |
| In / out / net calls | all | 9 of 9 (7 in, 1 out, 1 net) |

What it took to get there (all logged in DECISIONS.md):
- the pose search's finite-difference step (MATLAB found a wrong pose);
- the readout time as a per-mode prior;
- a ball meeting the net plane below the tape is a net, never a bounce;
- a flight that fits badly is tried as two flights, before and again after merging, and a split is never merged back. This found a hit hidden 50 ms before a cut.

Still to watch:
- **Worst bounce error, 11 cm.** It is on the bounce just before the net ball, whose flight is short.
- **Camera 2's readout time** settles 2.5 ms off its true value. Timing and positions are unaffected, because the time is judged at the middle row.

Both go on the real-footage retune list.

## Chris's 15 Nov additions

- **Calibration with no layout assumed.** The pose is searched all round the court from the lines alone. The court's half-turn twin is settled by both cameras agreeing on the ball and the players. The crossing angle goes into session.json, and weak zones go into the ntfy alert.
- **Courts in the app.** Name, layout, lens mode, indoor and mount photo, all on the phone. "Playing here now" labels the next session. An indoor court sends only an indoor flag, and the PC reruns from the physics stage.
- **PC uploader and answer loop.** Indoor flags and identity answers rerun only the stages they affect, then re-upload.

## Detector loop, opponents and spin kinds (Chris, 15 Nov)

- **Ball check.** The PC picks frames and crops them, and the app shows them one at a time.
- **"This looks wrong"** on each shot card, and **"missed a shot here"** in rally videos.
- **Test set and auto-labels** are kept apart.
- **Retraining** runs on the GPU or the CPU. A new model is promoted only when recall and precision both hold, and every attempt is logged.
- **Weekly message** with the retraining results and open flags. MATLAB CI covers this (learnTest, including a small training run on the CPU).
- **Opponents:** prompt, list and pages, kept in memory until the cloud exists.
- **Spin** is shown by kind (topspin, slice, flat).
- **Tile:** "N frames to check" at the lowest priority. The launcher still has to learn this state.

## Design preview

[docs/preview](../preview/README.md): the app's real screens on a synthetic 90-minute session, a launcher tile mockup, and the PC's MATLAB plots.

## Fit study, first run (16 Nov) — SYNTHETIC

400-shot study (366 shots in 79 rallies, 90 minutes), truth model unlike the fitter. Camera 2's clock drift (40 ppm) was not estimated, so only rallies 1 to 7 (about 15 minutes) were reconstructed: 51 shots. On those:

| Measure | Median | 90th percentile | Target |
|---|---|---|---|
| Hit time error | 1.3 ms | 16 ms | |
| Speed at contact | 1.2 mph | 3.3 mph | 2 mph for 90% (AC-07) |
| Bounce position | 4.4 cm | 11.5 cm | median 5 cm (AC-08) |
| Spin effect | 23 cm | 85 cm | 10 cm (AC-10) |
| Net clearance | 1.3 cm | 4.3 cm | |
| rpm | 33% | 90% | 10% (AC-11) |
| In / out / net calls | 45 of 45 right | | all |

Item 10 (the 11 cm bounce): after a short flight (< 0.25 s to the next hit) 2 shots, median 12 cm; all others 4.2 cm median. Too few short flights to settle it; the rerun has more.

The drift is now estimated window by window (DECISIONS 16 Nov, TV-SYNC-02). Spin effect errors flip sign with the hitter, which points at the wind error (found [1.9 -1.0] m/s against a mean truth of [1.5 -0.8]) being taken up as spin; to check on the rerun. Full output: the CI job `fit-study`.
