# 21 Nov: answers to the overnight report, home tests, Tuesday

Chris's message of 21 Nov, items 1 to 7 (items 8 to 11 were cut off in the message). Numbers are from synthetic footage, the Python twin on Chris's own footage, or CI, as each line says. Nothing has run on the phone or the Legion.

## 1. Curve tile
- **Now:** the tile shows from **1 ft** (Chris: B), and only when the curve is at least **twice its own uncertainty**. Older session files don't carry the uncertainty; for them the 1 ft limit alone applies.
- **The uncertainty:** each fitted flight now carries the covariance of its parameters (from the fit's own pixel error and its priors). It is carried through to the spin effect and the curve. Checked against 30 refits of one flight with fresh pixel noise: predicted 4.4 cm against 4.3 cm of real scatter for the curve, 7.9 cm against 7.5 cm for the spin effect; the true curve lay within twice the predicted uncertainty in 30 of 30 fits.
- **What it can't see:** anything the flight model leaves out. The uncertainty comes from pixel noise and the fit's priors only.

### 1b. How the per-shot rule does (shot study, CI run 57, 201 shots, Tuesday's set-up)
In calm air (only a steady wind), shots with a curve truly of each size:

| Rule | Shown: truly 1 ft or more | 0.5 to 1 ft | **under 0.5 ft (wrong)** | wrong side |
|---|---|---|---|---|
| 2 × its own uncertainty | 18 of 18 | 42 of 45 | **109 of 119** | 21 |
| 3 × its own uncertainty | 18 of 18 | 42 of 45 | **105 of 119** | 20 |
| 2 × and 0.5 ft | 18 of 18 | 33 of 45 | 25 of 119 | 0 |
| **1 ft (now)** | 14 of 18 | 12 of 45 | **1 of 119** | 0 |

**The per-shot rule as asked does much worse than the fixed 1 ft.** The fit's own uncertainty is about 1.5 cm, because 450 points at 4K240 pin the path down very well. But the curve's real error is about 6 cm (median) even in calm air: the real error sat within twice the fit's own uncertainty in only 18 of 182 shots. Nearly all of it is **model error**, not noise: the fit holds lift constant through a flight, while real lift falls as the ball slows and the spin decays (section 4b). A rule built on the fit's uncertainty can only work once that model error is in the uncertainty, or gone.
- **What the app does now:** 1 ft, and the twice-its-uncertainty guard on top. The guard almost never bites (the uncertainty is tiny), so in practice it is the 1 ft rule.

### 1c. With gusts (about 1 m/s)
| Rule | Shown: truly 1 ft or more | 0.5 to 1 ft | under 0.5 ft (wrong) | wrong side |
|---|---|---|---|---|
| 2 × its own uncertainty | 18 of 18 | 42 of 43 | 112 of 120 | 46 |
| 2 × and 0.5 ft | 16 of 18 | 30 of 43 | 50 of 120 | 18 |
| **1 ft (now)** | 15 of 18 | 5 of 43 | **13 of 120** | **5** |

With gusts even 1 ft shows a curve on about 1 straight shot in 9, and 5 on the wrong side. The fit's uncertainty can't flag them: within one flight a gust looks exactly like sidespin. **My recommendation:** keep 1 ft. Make the per-shot rule work only once the model error is in the uncertainty; that needs real flights to measure it, so the earliest is after Tuesday (the machine repeats show the real scatter).

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
- **Camera 2 following the neighbours' ball through rally 2's serve: cause found and fixed.** Each camera's 2D tracker links spots by motion alone. Where your ball and the neighbours' pass close in one camera's picture, a track can run on along the other ball. In CI the camera-2 track that held your serve was mostly the neighbours' ball, so the gate rightly dropped it as "mostly outside", with your serve in it. A local run of the neighbours test with today's code shows the same mechanism on a smaller scale (Octave chains slightly differently from MATLAB): the neighbours' track took your ball for 2 frames where the two crossed.
- **CI run 58 showed it exactly:** a camera-2 track holding 153 of your points and 463 of the neighbours', dropped whole as "mostly outside", your serve with it. The tracker wasn't switching once; it was alternating between the two balls.
- **Fix:** before pairing, a track's points are sorted by which of the other camera's tracks they pair with. Points whose main partner is in view but doesn't match them, while another track does, metres off the track's own path, go into a track of their own. Each piece is then judged on its own: the neighbours' piece is dropped, yours kept. A gap in the other camera's track moves nothing, so the stray case above is unaffected.
- **Tests:** a camera-2 track that is the neighbours' ball until frame 79, then yours: before 0 of your 40 points kept, now 40 of 40. One that alternates every frame: before 0 of your 33, now 33 of 33. None of the neighbours' points kept in either.
- **A first version made the neighbours test worse in CI (run 59: 4 of 9 shots, 40% of your ball lost).** It also cut camera 1's clean track of your ball, because camera 2's tracks were mixed, and a later step then threw out half of the pieces as duplicates. Fixed three ways: both cameras are judged against the other camera's tracks as found; a point is compared with the track's own path only near its own points in time; and the duplicates step acts only where two tracks really have points at the same moments. New test: two camera-2 tracks that swap the two balls in blocks. Camera 1's track stays whole, and 111 of your 120 points come back. CI run 60 checks the full neighbours test; if it is not at least as good as before (7 of 9), the split is switched off (one setting) and the rest stays.
- **Why this matters on real courts:** both fixes are about the one weakness of pairing by sight lines: two balls can line up in one camera. The pipeline now trusts a pairing only when it agrees with the path, and trusts a 2D track only while the other camera agrees it is one ball. The next neighbours-test run in CI shows whether your serve comes back.

## 4. Spin
**AC-11, proposed (the spec is unchanged until you say yes):**

| | Now | Proposed |
|---|---|---|
| AC-11 Synthetic rpm recovered (true lift known) | within 10% | median within 15%, 90% within 35%; rpm is secondary and always shown ±25% (TV-SPN-03, 04) |
| Measured (shot study, run 56) | | median 12% with gusts, 10% calm; 90th percentile 31% with gusts, 22% calm: met |

### 4b. The spin-effect tail (90th percentile about 26 cm)
CI run 57, calm air, the worst tenth of the shots (errors of 26 cm or more, 19 shots) against the rest, medians:

| | Tail | Rest |
|---|---|---|
| true spin effect | **317 cm** | 152 cm |
| speed | 67 mph | 62 mph |
| hit distance from the net | 14.7 m | 12.5 m |
| fit error | 1.28 px | 1.04 px |
| error ÷ the fit's own uncertainty | **19** | 6 |
| kinds | 12 forehands, 4 serves, 2 backhands, 1 machine | |

**The tail is the heavy-spin, fast, deep shots, and the error is model error.** Fitting the fit's own constant-lift model to perfect true flights (no noise, no wind) gives a median error of 11 cm and up to 34 cm on the heaviest spins, always the same way (about 3% of the effect, overstated). The path itself fits to 1 mm; the error comes when the spin is taken away to find where the same shot would have landed without it.

### 4c. A fit whose lift follows the spin
Built as an option: the lift follows the spin parameter as the ball slows, and the spin decays (matches an ode45 flight to 0.01 mm). On perfect flights (12 shots each, median / worst spin-effect error):

| The true ball | Constant lift (today) | Lift following spin |
|---|---|---|
| spin decays faster than the fit assumes (3 s against 5) | 4.7 / 20 cm | 4.6 / 13 cm |
| decays slower (8 s), lift 15% stronger | 13.5 / 44 cm | 2.6 / 7.5 cm |

It helps even when its own assumptions are wrong. One caveat: its lift curve has the same shape as the synthetic truth's, so on real balls the gain may be smaller.

**On the same 201 shots with gusts (CI run 58):**

| | Constant lift | Lift following spin |
|---|---|---|
| Spin effect error, median / 90th | 8.8 / 26.4 cm | **7.4 / 22.8 cm** |
| rpm error, true lift known, median / 90th | 12% / 31% | **6% / 16%** |
| Sideways curve error, median / 90th | 9.3 / 35.6 cm | 9.2 / 33.4 cm |
| Curve tile: wrong / wrong side (1 ft) | 13 / 5 | 11 / 4 |
| Speed, bounce, calls | 0.48 mph, 1.7 cm, 183 of 183 | 0.47 mph, 1.7 cm, 183 of 183 |
| Fitting time (the study) | 47 min | 89 min |

**Adopted as the default** (decision logged; one setting to undo). It meets AC-11 as written at the median (6% against 10%), but not for every shot (90th percentile 16%). So the question changes: either AC-11 stays as it is and I report the 90th percentile beside it, or it is relaxed as proposed above.

## 5. Tuesday checklist (manual 16)
- Recording: **about 40 minutes** (the clips add up to 37 to 41), corrected from 20.
- **Flicker clip** per camera (16.2 step 3): a plugged-in LED or fluorescent lamp on a plain wall, room dark, 15 s at Tuesday's shutter; check with the phone's slow motion that the lamp flickers. Measured at home if possible (17.3). The readout measurement is checked at 240 frames a second (the lamp's 120 Hz is half the frame rate, so the bands alternate; it still finds 3.5 and 6.0 ms to within 0.05%).
- **Batteries in the cold (16.6):** not known for this camera. One review: about 74 minutes of continuous 4K240 with air round it, 35 boxed in; batteries give 20 to 40% less near freezing. Forty minutes plus standby on one internal battery in the cold is tight. **Drop first:** the 4K200 clip, then the last empty-court clip, then two of the four machine settings, then the target tosses. **Never drop** the still balls or the 2-metre drops. The weekend runtime test gives the real number.
- **Synthetic machine repeats (shot study, run 57):** the landing spread per setting is now found within 2.3 cm of the truth (31.9 to 94.0 cm found against 31.1 to 94.3 cm), and the speed spread within 0.35 mph.
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
