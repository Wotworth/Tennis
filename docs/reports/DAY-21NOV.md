# 21 Nov: answers to the overnight report, home tests, Tuesday

Chris's message of 21 Nov, items 1 to 7 (items 8 to 11 were cut off in the message). Numbers are from synthetic footage, the Python twin on Chris's own footage, or CI, as each line says. Nothing has run on the phone or the Legion.

## 1. Curve tile
- **Now:** the tile shows from **1 ft** (Chris: B), and only when the curve is at least **twice its own uncertainty**. Older session files don't carry the uncertainty; for them the 1 ft limit alone applies.
- **The uncertainty:** each fitted flight now carries the covariance of its parameters (from the fit's own pixel error and its priors). It is carried through to the spin effect and the curve. Checked against 30 refits of one flight with fresh pixel noise: predicted 4.4 cm against 4.3 cm of real scatter for the curve, 7.9 cm against 7.5 cm for the spin effect; the true curve lay within twice the predicted uncertainty in 30 of 30 fits.
- **What it can't see:** gusts. The uncertainty comes from pixel noise and the fit's priors, so a gust that pushes the ball sideways looks like a sure curve to it. The shot study compares the rules with gusts and in calm air (section 1b, when CI finishes).

## 3. Real test-set balls of 5 px and more that round 5 missed (4)
Looked at by eye in private crops (frames not in the repository):

| Ball | Score | What it is |
|---|---|---|
| Video 1, 9.3 px | 0.48 (just under 0.5) | On the racquet strings at the moment of contact |
| Video 1, 6.2 px | 0.23 | In flight, right beside the player's head as it turns: the three-frame picture the classifier sees is full of the head's movement |
| Clay video, 5.5 px | no spot | A ball lying still on the court, seen through the net |
| Clay video, 4.8 px | 0 | Another still ball, behind the net mesh |

**What the synthetic pictures leave out:** the size study draws a lone moving ball on a court (sometimes a line). Real misses come from **what touches or surrounds the ball**: the racquet at contact, and a moving body right next to it. The two clay ones are balls at rest; the detector looks for moving spots by design, so it doesn't find them, and they don't matter in play. Small or blurred balls are not the problem.
- **Effect on measurement:** small. At contact the flight fit runs the path to the racquet from both sides; a ball beside a player is found again a frame or two later.
- **Next (not started):** draw balls touching a racquet and right beside a moving figure in the training pictures, and count still balls apart in the test-set report (the labels themselves stay as they are).

## 2. Ball identity across the two cameras
**Mis-paired points (the stray at 0.7 to 1.4 m): cause found and fixed.** The stereo gate pairs each point of a track with the other camera's tracks. A point that doesn't fit its own partner may pair with any other track within 4 px. That was meant to catch a 2D tracker that swaps onto a neighbour's ball for a few frames. But the epipolar test can't tell balls apart along a line: any pixel on the other camera's epipolar line passes it. So where the stray's own partner had a gap in camera 2, its camera-1 points paired with another ball's track and triangulated in mid-air.
- **Fix:** such a point is kept only if it lies on the track's own path, within 0.5 m of where the track's own partner-paired points put it; otherwise it is dropped as "paired with another ball". Swaps onto a neighbour's ball land outside the court and are dropped as before.
- **Test (adjacentGateTest):** a stray rolls across your court, camera 2 loses it for 15 frames, and a ball in the air lies exactly on camera 1's sight line through it. Old code: the stray is kept, with 11 of the 15 mid-air points. New code: rejected as rolling, even on the old every-point rule.
- **Camera 2 following the neighbours' ball through rally 2's serve:** section 2b, from a local run of the neighbours test with today's code.

## 4. Spin
**AC-11, proposed (the spec is unchanged until you say yes):**

| | Now | Proposed |
|---|---|---|
| AC-11 Synthetic rpm recovered (true lift known) | within 10% | median within 15%, 90% within 35%; rpm is secondary and always shown ±25% (TV-SPN-03, 04) |
| Measured (shot study, run 56) | | median 12% with gusts, 10% calm; 90th percentile 31% with gusts, 22% calm: met |

**The spin-effect tail (90th percentile 27 cm):** section 4b, from the shot study's new tail table (CI run 57).

## 5. Tuesday checklist (manual 16)
- Recording: **about 40 minutes** (the clips add up to 37 to 41), corrected from 20.
- **Flicker clip** per camera (16.2 step 3): a plugged-in LED or fluorescent lamp on a plain wall, room dark, 15 s at Tuesday's shutter; check with the phone's slow motion that the lamp flickers. Measured at home if possible (17.3). The readout measurement is checked at 240 frames a second (the lamp's 120 Hz is half the frame rate, so the bands alternate; it still finds 3.5 and 6.0 ms to within 0.05%).
- **Batteries in the cold (16.6):** not known for this camera. One review: about 74 minutes of continuous 4K240 with air round it, 35 boxed in; batteries give 20 to 40% less near freezing. Forty minutes plus standby on one internal battery in the cold is tight. **Drop first:** the 4K200 clip, then the last empty-court clip, then two of the four machine settings, then the target tosses. **Never drop** the still balls or the 2-metre drops. The weekend runtime test gives the real number.
- **The check file is now 30 s:** some reviews say the Mission 1 Pro stops 4K240 after 10 seconds, others say not. If yours does, Tuesday changes (sent to your phone this morning).

## 7. Home tests (manual 17) and their processing
| Test | What you do | Tool (tested on made-up data) |
|---|---|---|
| a. Lens | checkerboard, 90 s per camera and lens | `vision/ml/lens_from_checkerboard.py` here, `tv.lens.fromCalibration` in the pipeline: standard and fisheye models, the better one kept. On synthetic views of a Linear-like and a Wide-like lens: focal length within 0.4 px, centre within 0.15 px; MATLAB projects exactly as OpenCV does (lensCalibTest) |
| b. Readout | flicker clip, 15 s per camera | `tools/readoutFromFlicker.m` (readoutTest at 240 frames a second) |
| c. Sync and drift | one long recording, claps at 0, 10, 20, 30 min | `tools/syncFromClaps.m`: on a made-up 31-minute pair, offset within 0.02 ms and a 40 ppm drift found as 40.0 (clapSyncTest) |
| d. Battery and heat | the same recording, left running in the cold until it stops | `tools/runtimeFromFiles.m`: minutes recorded, gaps between chapters, card used per minute |

Tuesday's steps covered at home are marked *home* in section 16 and skipped. c and d share one recording because both need the cameras running a long time; the big files are not uploaded whole (the LRV files and a list of sizes; I fetch the minutes round each clap).

## 6. First Mission 1 Pro files
Waiting for the files. `tools/checkCameraFile.m` is ready (name and chapters, LRV, codec and bit depth, picture size, every frame's time, timecode, telemetry, shutter, ISO, sound).
