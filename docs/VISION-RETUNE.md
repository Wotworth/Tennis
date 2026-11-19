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
| Timing | `+tv/+sync/clockLine.m` | Window length (10 min) and search around the drift line (±30 ms) | Real camera drift over a 2-hour session (TV-SYNC-02) |
| Adjacent courts | `+tv/+court/interest.m` | Court of interest: 5 m behind the baselines, 2 m beyond the doubles sidelines, 12 m high (TV-ADJ-01) | Real courts: how far players run back, how close the next court is |
| Adjacent courts | `+tv/+recon/gateTracks.m` | Epipolar tolerance (4 px), inside share (50%), paired share (30%), top speed (75 m/s), gap allowed when interpolating (3 frames), same-ball distance (2 m), rolling ball (under 0.3 m for 0.3 s) (TV-ADJ-02 to 04) | Real footage on busy public courts; the reject log (TV-ADJ-06) shows what each costs |
| Court lines | `+tv/+calib/imageLines.m` | Minimum straight length (60 px), straightness (1.5 px), merge angle and offset (1.5 deg, 4 px) | First real footage (iPhone, 17 Nov); recheck on the MISSION 1 PROs |
| Court from lines | `+tv/+calib/courtFromLines.m` | Across/along angle (15 deg), lines kept per class (8), poses refined (12), first and final tolerances (8 px, 3 px), explained-paint distance (0.12 m) | First real footage; recheck on each new court |
| Clips of an edited export | `+tv/+media/cuts.m` | Scene-score spike (0.03, 8 x neighbours, +-6 frames), shortest clip (1 s) | Only for edited one-camera footage (SwingVision exports) |
| One-camera run | `+tv/+pipeline/runSingle.m` | Overlay boxes, line settings, starting lens width (65 deg), bounce turn (1.5 px/frame), player sampling (2 per s), detector colours (pale ball), still-track speed (1.5 m/s) | Each new phone or HERO7 test |
| Steadying | `+tv/+calib/steady.m` | Largest camera movement corrected (40 px); whole-pixel shifts only, no rotation or zoom | If a mount sways more than 40 px, or the picture rotates |
| Player tracks | `+tv/+track/dropAtPlayer.m` | Share of a track's sample points inside a player's outline for it to be a racquet or shirt (all); the outline's widening (0.6 of the player's width each side) | If balls hit close to a player are dropped, or racquets survive |
| Steered search | `+tv/+track/follow.m` | Looser colour and contrast inside the window (0.6), window size (8 px, more for a fast ball), frames tried past a track's end (30), misses allowed (3) | If tracks grow onto net tapes or fences, or faint balls are still missed |
| Points in raw footage | `+tv/+pipeline/runSingle.m` | Processing window (30 s), gap that ends a point (4 s), shortest point (1.5 s) | First raw sessions |
| Still tracks | `+tv/+track/dropStill.m` | Slowest ball counted as moving (1.5 m/s at the far end of the court), measured over 0.25 s | If balls in play are dropped, or balls lying still survive |
| Adjacent courts | `+tv/+players/keepCourt.m` | Share of a person's time inside (60%) (TV-ADJ-05) | Opponents who wander wide; neighbours by the shared sideline |
| Timing | `+tv/+pipeline/defaults.m` (readoutPrior), `+tv/+recon/refineSession.m` | Readout prior (8 ms ± 1 ms): replace with each camera's flicker measurement (TV-SYNC-06, `tools/readoutFromFlicker.m`) and tighten to ± 0.1 ms; drift and wind priors, rounds | Flicker clip per camera and mode (TV-PH-0); spec chooses the mode at the end of TV-PH-2 |
| Ball | `+tv/+detect/ballCandidates.m` | Every threshold; optic-yellow hue range in real light; size range at 4K | Labelled frames from trials (then the learned detector, TV-PH-5) |
| Ball | `+tv/+learn/netLayers.m` | The learned detector's input size, width and depth | The PC's GPU and the first 20,000 auto-labels |
| Ball | `+tv/+detect/volumeMask.m` | Margin; the 9 px widening of the exact sight-line test | First sessions |
| Ball (learned) | `+tv/+detect/motionProposals.m` | Neighbours 1/30 s away; shift tolerance (2 px); threshold (median + 8 robust deviations of the frame's own difference, never below 18); size limits (2 diameters wide, 9 long) | The fixed test set: share of balls proposed (19 of 20 on the iPhone frames) |
| Ball (learned) | `+tv/+detect/ballSizeMap.m` | Nearest a ball in play comes to the camera (4 m) | Layouts where play comes closer |
| Ball (learned) | `+tv/+detect/ballNet.m`, `vision/models/` | The weights: retrain with each new camera's footage (drawn balls and self-training), then with TV-DET-05 auto-labels; crop size (48 px) | The fixed test set, after every retrain |
| Ball (learned) | `+tv/+track/chains.m` | Gap (8/60 s), gap and turn costs (0.4, 0.15), top speed (12 diameters per 1/60 s plus 6 px), chain worth (6), shortest chain (5 frames) | The fixed test set's tracker score |
| Bounces, one camera | `+tv/+events/bounceKind.m` | How far a ball must have come to count as in play (2.2 m within 1 s); a dribble is two bounces on the spot within 3 s and 0.7 m; next-court and in-the-air turns by their ground point | Sessions with both players' serves in view; the two-camera run replaces the distance test |
| Points, one camera | `+tv/+events/pointsFromTracks.m`, `+tv/+pipeline/runSingle.m` (offBounceS) | Quiet that ends a point (4 s), shortest point (1.5 s), cut either side of a dribble (0.5 s), shortest track that counts (0.5 s), flight trimmed either side of a next-court bounce (0.75 s) | Raw sessions checked against the score |
| Tracks | `+tv/+track/ball2d.m`, `+tv/+track/splitEvents.m` | Gates, noise, minimum length, first jump; split window and thresholds | Trials, against hand-checked rallies |
| Flights | `+tv/+recon/segments.m`, `+tv/+recon/fitSegment.m` | Event clustering, edges, merge and split tests; Huber limit; lift priors (0.25, and 0.05 for flights under 0.3 s); 6 px outlier cut, at most 10% of a flight | Trials; drop test (AC-09) and radar (AC-07) |
| Events | `+tv/+events/classify.m` | 0.3 m bounce height, 6 m/s net drop, 3 m/s toss limits | Trials with net cords and drop shots |
| Players | `+tv/+players/detect.m` | Use the pretrained person detector ('acf' or better); thresholds, height range, magenta range | Trials with the magenta cap (TV-PLY-03, 06) |
| Players | `+tv/+players/track.m` | Same-person distance, gates, speed, colour weight, cap evidence | Changeovers in real sessions (AC-13) |
| Metrics | `+tv/+metrics/shot.m` | Confidence formula, 2.5 m hitter limit | AC-06, AC-13 |
| Spin | `+tv/+metrics/spin.m` | The C_L(S) table: the spec's straight line, to be fitted to Cross & Lindsey | Literature fit; AC-11 |
| Flights | `+tv/+recon/segments.m` | Merge cap (3 px) and junk limit (5 px) | Trials: stray tracks (other balls, shoes) and real merges |
| Flights, one camera | `+tv/+recon/segments.m` | `oneMin` (6 detections with pins at both ends), `oneMinLoose` (15 with one pin), `oneJoinS` (0.08 s to a neighbour that still pins), `oneRms` (1.5 px), `oneJumpMps` (4 m/s: the change of velocity that makes a real event); the pins' sizes (3 cm at a bounce; 3 cm plus half the gap's travel at a hit) | Trials: flights with one camera blocked, checked against stretches both cameras saw |
| Ball detector, first pass | `vision/models/ballnet_v4_pre.json` (`threshold`) | Passes 99.8% of ball examples | Re-set whenever the classifier is retrained (`vision/ml/train_pre.py`) |
| Ball detector, model | `vision/models/ballnet_v5.json` (`+tv/+detect/ballModel.m`; another file only by hand, `ballNetFile`) | Round 5, adopted 19 Nov for every court, indoors too: rejects shadows; a ball darker than the court behind it is rejected too (3 of 71 hand-labelled balls were darker, and it found all 3). Round 4 (`ballnet_v4.json`) does not use colour | First indoor footage and any unusual ball colour: count misses with both before changing anything |
| Ball detector, where the centre is | `+tv/+detect/ballCentre.m` | Each scored spot is placed on the middle of what differs from the empty court: threshold 4 robust deviations over the patch's own level; the piece may be up to 6 times the moving spot's area (or a disc as wide as the spot is long); the centre may move at most half the spot's length plus 1.5 px. Synthetic truth: 0.30 px to 0.14 px median error; clay clip: track jitter 0.67 to 0.49 px | The first two-camera footage: flight-fit residuals with and without (`opts.refine`) |
| Calibration, line pixels on real footage | `+tv/+calib/lineOptsFor.m` | Ridge contrast 20; reach 3 and 7 px and minimum piece length 40 px at 1920 px wide, scaled with the picture's width | The Hero 7 clip from beside a court (hard and clay); they were set on phone videos from behind a baseline |
| Calibration, pose search | `+tv/+calib/searchPose.m` | `supportOk` (0.85: below it the look-alike shifts are tried), `supportTie` (0.1), `hopFrom` (3 poses), the range guard (5 m beyond `maxRange`, 1 to 10 m high) | First GoPro footage from beside a court, hard and clay |
| Calibration, when to ask | `+tv/+pipeline/defaults.m` (`minLineSupport`, `maxTapRms`) | `minLineSupport` 0.35, PROVISIONAL: a fit with paint under less of its near-half lines is doubtful and the session is held for the four corners (TV-CAL-21). Set midway between the two wrong fits seen on real pictures (0.16 and 0.18) and the lowest right one (0.54); all of those are phone pictures from behind a baseline. `maxTapRms` 0.01 of the picture's width: taps further than that from a court's corners are asked for again | **The Hero 7 clip from beside a court sets `minLineSupport`** (Chris, 19 Nov); real taps on real pictures set `maxTapRms` |
| Calibration, from tapped corners | `+tv/+calib/fromCorners.m` | The line refinement stays within `maxMove` 0.7 m and `searchDeg` 2 degrees of the tapped pose (less than an alley, 1.37 m, so it cannot hop to the neighbouring line) | Real taps on real pictures: how far a finger really is from the corner |
| Heat | `+tv/+ops/thermalGuard.m`, config `pc.tempLimitC` | CPU 90 C and GPU 80 C limits, 5 C resume, 30 min longest wait | The day-one benchmark's peak temperatures, then summer sessions |
| Retention | `+tv/+ops/retention.m` | Rally segments kept 3 months are not cut out yet | TV-OPS-03 once the archive fills |
| Synthetic footage | `+tv/+synth/renderBackground.m`, `+tv/+synth/renderFrame.m`, `+tv/+synth/renderAudio.m` | Make the generator look and sound like real footage (shadows, compression, voices) | Compare with trial footage; then re-run every synthetic test |
| Synthetic footage | `+tv/+physics/bounce.m` | Court restitution and friction | Trials (bounce kick) |

## Known limits of the synthetic tests

- Frames are 960 × 540 with the ball drawn 4 times larger, so it covers about as many pixels as at 4K. Real 4K footage is 16 times more pixels per frame: detection speed on the PC is untested.
- The ball is never hidden behind a player or the net post in the synthetic footage.
- Players are simple figures, not people; the pretrained person detector is not exercised.
- Only one layout (side fence, near the baselines) is rendered end to end; the back-fence corner layout is tested for calibration only.
