# Tennis Vision: what real footage must retune

Everything in `vision/` was built and tested without cameras: on synthetic footage the code renders itself (`tv.synth`), GoPro's published lens figures, and GoPro's own sample telemetry. Every number tuned on those is marked `RETUNE(...)` in the code. This list collects them, stage by stage, with the footage or test that will set each one. `vision/tests/retuneTest.m` fails if a file gains a `RETUNE` note that is not listed here.

The first real footage is the TV-PH-0 lens calibration and trial sessions; most items below are retuned in TV-PH-2 on those.

| Stage | File | What to retune | Set it with |
|---|---|---|---|
| Lens | `+tv/+lens/build.m` | The whole lens model: published angles stand in for a calibration | TV-CAL-01 checkerboard clips, each camera and mode |
| Placement | `+tv/+calib/crossingReport.m`, `+tv/+pipeline/defaults.m` (minCrossDeg) | Usable crossing angle (20°) | Bounce targets (AC-08) in the weakest zone |
| Placement | `+tv/+placement/corners.m` | Layout 2 (back-fence corners): rerun with the calibrated lens. Its weakest zone is over the cameras' sideline at the net (21–42° on court, 12–36° in the air, depending on the corner); ball 3.1–4.1 px at the far corner | TV-CAL-01 lens; bounce targets (AC-08) at the net on the cameras' side; the first layout 2 session |
| Court lines | `+tv/+calib/linePixels.m` | Ridge contrast (6 levels), reach (3 px), colour limit (0.5) | Backgrounds from sunny, cloudy and shaded sessions; worn lines |
| Court lines | `+tv/+calib/courtPose.m`, `+tv/+calib/searchPose.m` | Line caps (12 then 3 px), search ranges and steps | First sessions in each layout (side fence; back-fence corners) |
| Court lines | `+tv/+calib/background.m`, `+tv/+pipeline/run.m` | Background from a quiet minute (~200 frames), not the whole file | First sessions: players standing still stay in a median |
| Twin choice | `+tv/+calib/resolveSymmetry.m` | Weight of player agreement against ball agreement | First sessions in each layout |
| Rallies | `+tv/+rally/fromAudio.m` | Onset threshold, 3 s cadence limit, minimum sounds; add the ball-motion check (TV-RAL-01) | Sessions with talking, wind and neighbouring courts (AC-03) |
| Timing | `+tv/+sync/fromRays.m` | Search range (±60 ms) | Real timecode/GPS start error (TV-SYNC-01) |
| Timing | `+tv/+pipeline/defaults.m` (readoutPrior), `+tv/+recon/refineSession.m` | Readout prior (8 ms ± 1 ms): replace with each camera's flicker measurement (TV-SYNC-06, `tools/readoutFromFlicker.m`) and tighten to ± 0.1 ms; drift and wind priors, rounds | Flicker clip per camera and mode (TV-PH-0); spec chooses the mode at the end of TV-PH-2 |
| Ball | `+tv/+detect/ballCandidates.m` | Every threshold; optic-yellow hue range in real light; size range at 4K | Labelled frames from trials (then the learned detector, TV-PH-5) |
| Ball | `+tv/+learn/netLayers.m` | The learned detector's input size, width and depth | The PC's GPU and the first 20,000 auto-labels |
| Ball | `+tv/+detect/volumeMask.m` | Margin, dilation and closing at 4K | First sessions |
| Tracks | `+tv/+track/ball2d.m`, `+tv/+track/splitEvents.m` | Gates, noise, minimum length, first jump; split window and thresholds | Trials, against hand-checked rallies |
| Flights | `+tv/+recon/segments.m`, `+tv/+recon/fitSegment.m` | Event clustering, edges, merge and split tests; Huber limit; lift priors (0.25, and 0.05 for flights under 0.3 s); 6 px outlier cut, at most 10% of a flight | Trials; drop test (AC-09) and radar (AC-07) |
| Events | `+tv/+events/classify.m` | 0.3 m bounce height, 6 m/s net drop, 3 m/s toss limits | Trials with net cords and drop shots |
| Players | `+tv/+players/detect.m` | Use the pretrained person detector ('acf' or better); thresholds, height range, magenta range | Trials with the magenta cap (TV-PLY-03, 06) |
| Players | `+tv/+players/track.m` | Same-person distance, gates, speed, colour weight, cap evidence | Changeovers in real sessions (AC-13) |
| Metrics | `+tv/+metrics/shot.m` | Confidence formula, 2.5 m hitter limit | AC-06, AC-13 |
| Spin | `+tv/+metrics/spin.m` | The C_L(S) table: the spec's straight line, to be fitted to Cross & Lindsey | Literature fit; AC-11 |
| Retention | `+tv/+ops/retention.m` | Rally segments kept 3 months are not cut out yet | TV-OPS-03 once the archive fills |
| Synthetic footage | `+tv/+synth/renderBackground.m`, `+tv/+synth/renderFrame.m`, `+tv/+synth/renderAudio.m` | Make the generator look and sound like real footage (shadows, compression, voices) | Compare with trial footage; then re-run every synthetic test |
| Synthetic footage | `+tv/+physics/bounce.m` | Court restitution and friction | Trials (bounce kick) |

## Known limits of the synthetic tests

- Frames are 960 × 540 with the ball drawn 4 times larger, so it covers about as many pixels as at 4K. Real 4K footage is 16 times more pixels per frame: detection speed on the PC is untested.
- The ball is never hidden behind a player or the net post in the synthetic footage.
- Players are simple figures, not people; the pretrained person detector is not exercised.
- Only one layout (side fence, near the baselines) is rendered end to end; the back-fence corner layout is tested for calibration only.
