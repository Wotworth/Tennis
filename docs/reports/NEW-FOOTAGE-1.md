# New footage 1: a GoPro Hero 7 clip and a long iPhone match

19 Nov 2026. Chris sent three links to check the methods against new courts and new light. None of the detector's training ever saw these. No frames from them are in the repository.

## What the three files are

| Link | What it is | Used |
| --- | --- | --- |
| 1 | The 25 Apr SwingVision export already in the session (same name and size) | Nothing new |
| 2 | An iPhone recording of a whole match, 3 Oct 2025: 78 minutes, 1920x1080, 60 frames a second, 3 GB. A blue hard court in low sun, with long hard shadows across it. No SwingVision overlay. | Minutes 10 to 15 (the file is larger than the session's free disk, so only that stretch was fetched) |
| 3 | A GoPro Hero 7 Black clip, 9 Sep 2024: 8.9 minutes, 2704x2028 (2.7K, 4:3), 60 frames a second. A green clay court in bright sun, the camera high at a back corner. No overlay. | All of it for calibration; 5 seconds for the detector so far |

**The GoPro's lens mode is Wide.** The file itself can't say: it has been re-encoded by a cloud service and the GoPro's own data track is gone. But the picture shows it: the near baseline and the fence bow strongly, which Linear mode would straighten. It is also heavily compressed (5 Mbit/s for 2.7K, about a tenth of what the camera records).

## Camera calibration from the court lines

| Video | Result |
| --- | --- |
| iPhone match | **Worked at once.** Line error 1.0 px, every near-half line found, lens angle 64.7 degrees, camera 6.3 m behind the baseline and 2.35 m up. |
| GoPro, one-camera routine (as for the iPhone videos) | **Failed:** "no court line pattern found". |
| GoPro, the two-camera pipeline's own pose search | **Failed:** it returned a pose, but a wrong one. Drawn on the picture, its court is squashed onto the net. |

Why the GoPro failed, as far as I can tell:

1. **Clay lines are faint.** The line finder picked up the near baseline and parts of the sidelines, but the net tape is far brighter than any court line, and the search matched the court to the net tape.
2. **The lens model is a stand-in.** It is built from GoPro's published angles for current cameras; nothing has been measured, and the Hero 7's Wide mode is a little narrower. The spec already says the real lens must be calibrated first (TV-CAL-01).
3. **The camera sits higher and looks down more steeply** than the search's starting positions assume.

Two more searches, started near where the camera plainly is (higher, aimed more steeply down), did no better: one settled on the neighbouring court, the other on this court but turned and stretched, held by the net tape again.

This is the first real GoPro picture the calibration has seen, and it did not cope. It needs fixing before the two-camera trials. What I'd change, in order:

1. Score a pose by every court line having paint under it, as the one-camera routine already does, so one bright line (the net tape) cannot carry a wrong pose.
2. Make the line finder keep faint lines when they are long and straight (clay).
3. Use the measured lens of the camera in hand, not the published angles.

## The ball detector (round 4, no colour) on the new footage

I looked at a random sample of the spots the tracker called the ball, five frames around each. For the iPhone match the sample comes from the first 90 seconds processed; the rest is still running.

| | iPhone match, low sun (20 spots) | GoPro, bright sun, clay (16 spots) |
| --- | --- | --- |
| A ball | 13 | 8, all this court's |
| The ball's own shadow | 2 | 1 |
| A ball on the next court | 0 | 3 |
| Cars on the road beyond the fence | 0 | 4 |
| Leaves, a player's feet, or nothing I could see | 5 | 0 |

- **It finds the ball on both.** Different court surface, light and camera, and at 2.7K with a fisheye lens, with no change to any setting. On the GoPro stretch it followed this court's ball almost throughout, including when it was a few pixels across at the far end.
- **On the GoPro, 7 of the 8 wrong spots are outside the court.** With no fitted camera there was no court mask, so the next court and the road counted. With the camera fitted they are excluded before the detector runs.
- **The shadow is a new mistake, and round 4 made it possible.** Round 4 was trained to accept a dark ball on a pale court as readily as a pale ball on a dark one. In strong sun the ball's shadow is exactly that: a small dark thing moving like a ball. The earlier model rejected most dark-on-pale balls (it found 23 of 35 with light and dark swapped), so it would probably have rejected most shadows too; I have not run it on these clips.
- **Two of the 13 balls on the iPhone clip are not in play** (bounced before a serve, and in the server's hand). That is the tracker's "one ball in play" doing its job loosely, not a detector fault.
- These are precision figures only. I have not hand-labelled balls on these videos, so I can't yet say how many it misses.

## What to do about the shadow

A shadow darkens whatever is behind it without changing its colour. A ball brings its own colour. So the useful colour signal is not "what colour is this spot" (which changes with the light, and which round 4 showed adds nothing) but **"did the colour here change, or only the brightness?"** That holds under any light, because it compares the same patch of court with and without the thing on it.

I'd add that as two extra input pictures for the classifier and train it with shadows from these two videos as "not a ball" examples. It is the robust use of colour you described.

## Speed on these

One CPU core, with other jobs running beside it: 0.7 to 0.8 s a frame on the iPhone clip, 1.4 s a frame on the GoPro at 2.7K. Finding the moving spots is two thirds of that.

## Round 5, judged on stretches it never saw (19 Nov, overnight)

Chris asked for the new videos to be used for training, with a review document instead of the app. The detector was trained on the earlier part of each video and judged on a later stretch: frames 14,400 to 16,199 of the iPhone match clip, points 52 to 55 of the SwingVision clip, and two 10-second chunks of the GoPro clip. The pictures are in a private review page sent to Chris; none are here.

| Held-out stretch | Frames with a ball tracked: round 4, round 5 | Tracked spots that are shadows: round 4, round 5 | By eye, 12 random tracked spots are the ball: round 4, round 5 |
| --- | --- | --- | --- |
| iPhone match, 30 s | 868, 611 of 1,776 | 12.8%, 2.5% | 8, 9 |
| SwingVision clip, 4 points | 1,085, 968 of 1,450 | 12.1%, 1.9% | 9, 10 |
| GoPro, 20 s | 454, 391 of 1,184 | 6.2%, 0.3% | 7, 9 |

What round 5 still gets wrong on these: the far player's racquet head when it is the ball's colour (one stretch between points), a fast serve going away from the camera (lost at the far end by both models), and on the GoPro a faint streak across the clay near the camera that I cannot identify. Details and the test-set results: docs/reports/BALL-DETECTOR-1.md, round 5.

## The SwingVision export of the same match ("Dmetri 1", first 6 minutes)

Calibrated at 1.03 px to the same camera position as the iPhone match. Overlay read: 65 points, 175 shot labels, no unread ink. Of 59 bounce marks the tracker (round 4) had the ball at 29, a looser search found it at 27 more, nothing at 3. Ball tracked in 84% of in-play frames; an event at 68% of SwingVision's bounces and 70% of its shots.

## GoPro against iPhone: resolution and frame rate

Chris asked whether the GoPro clip's higher resolution and frame rate help. The frame rate is the same (59.94 against 60). The picture has 2.6 times the pixels (2704x2028 against 1920x1080), but in Wide mode they are spread over about twice the angle, so the tracked ball is **smaller**: 5.0 px across (median) against 8.0 px on the iPhone match and 7.5 px on the 16 Apr video. This copy is also 5 Mbit/s H.264 for 5.5 million pixels, against 5 Mbit/s HEVC for 2.1 million. So it does not help here. What matters is pixels across the ball (picture width over lens angle); Linear mode at the highest resolution is the setting to measure on the Mission 1 Pros.

## What carries over to the two GoPros

- The detector needed no change for a new camera, picture size, surface or light: it scales every candidate to the ball's expected size first.
- Shadows were the main new mistake outdoors; round 5 removes most, and with two cameras the 3D check is a second defence.
- Most wrong spots on the GoPro clip were outside the court until its area was known: the court mask (from calibration) matters as much as the detector.
- Calibration from court lines worked at once on hard courts and failed on clay through a fisheye. Linear mode removes the fisheye, not the faintness of clay lines against the net tape; the fit should require paint under every court line. To do before the trials, ideally on a Linear-mode clip.
- Fast serves going away from one camera are lost at the far end: the case for the second camera, with the one-camera fit (docs/reports/ONE-CAMERA-1.md) bridging the gaps.

## The two-camera calibration routine on real straight-lens pictures (19 Nov, found and fixed)

The one-camera routine (`tv.calib.courtFromLines`) fitted every court above, but it assumes a view along the court from behind a baseline. The two-camera pipeline uses `tv.calib.searchPose`, which assumes no layout (the GoPros will be beside the court) and until now had only seen synthetic pictures. Run on the iPhone court pictures, where the true camera is known and the lens is straight (as the GoPros' will be in Linear mode):

| Court picture | Before: distance from the true camera | After |
| --- | --- | --- |
| 3 Oct match (blue hard court, fence shadows) | 1.4 m: the whole court one doubles alley sideways (line support 0.55 against 0.97) | 0.00 m |
| Clay court (10 Nov iPhone video) | 13.3 m | 0.00 m |
| 25 Apr video | not run | 0.01 m |
| 16 Apr video | not run | 0.01 m |
| Synthetic, planned positions beside the court, Wide lens | 0.01 m and 1.67 m (in this session's Octave; MATLAB's pipeline test passed) | 0.01 m and 0.01 m |
| Synthetic, same positions, Linear lens | not tested | 0.02 m and 0.01 m |

What was wrong, and what changed:

1. **The winner was the pose matching the most line points.** A court moved sideways by one alley puts most of its lines on other real lines. Now each refined pose is judged line by line (`tv.calib.lineSupport`: the share of each near-half line with paint under it), and among the well-supported ones the pose matching the most points wins.
2. **Look-alike shifts.** When no pose is well supported, the best few are retried moved by the court's own line spacings (an alley or a singles half-width sideways, a service box lengthways).
3. **On clay the grid search never got near the true camera.** The one-camera routine's pose (from the lines' crossings) now joins the candidates where it finds one; from beside the court it finds none and adds nothing.
4. **A pose far outside the search range is refused.** One candidate 85 m away matched everything by squeezing the court onto a few pixels.

New test: `vision/tests/poseSearchTest.m` (both synthetic cameras, Wide and Linear). CI run 49 (MATLAB): 142 pass, including it and the end-to-end synthetic session; the 2 failures are the known adjacentTest sections.

### How much of that check is circular (Chris, 19 Nov)

"0.00 m from the true camera" above is agreement with `tv.calib.courtFromLines`, and since change 3 that routine's own pose is one of the candidates `searchPose` judges. On pictures from behind a baseline the check is therefore partly circular: the routine can agree with the one-camera routine by adopting its answer. With that candidate switched off (`'crossings', false`), `searchPose` by itself gives:

| Court picture | Without the line-crossing candidate | Its own line support |
| --- | --- | --- |
| 3 Oct match (blue hard court) | 0.00 m from the one-camera routine's camera | 0.96 |
| 16 Apr video (fenced hard court) | 0.01 m | 0.88 |
| Clay court (10 Nov) | **wrong** (34 m off) | 0.18 |
| 25 Apr video (pickleball tape, two courts in play behind) | **wrong** (42 m off) | 0.16 |
| Synthetic, beside the court, Wide and Linear (true camera known exactly; the candidate adds nothing from there) | 0.01 to 0.02 m | 0.95 to 1.00 |

So, stated plainly: by itself the layout-free routine agrees with the one-camera routine on the two clean hard courts (two methods, one answer: a real check), and fails on the clay court and the taped court, where the only reason the combined routine is right is that it adopts the one-camera routine's pose. From beside the court that candidate does not exist. **The Hero 7 clip from the side fence is the real test**, and clay or taped courts from the side are the cases most likely to fail it.

What protects a session meanwhile: both wrong answers carry a very low line-support score (0.16, 0.18, against 0.54 to 0.97 for every right one), and the pipeline now raises an alert when a camera's support is under 0.6 (`cfg.minLineSupport`) instead of carrying a doubtful camera position silently into the 3D work.

### Line-pixel settings in the two-camera path

`tv.pipeline.run` used the line-pixel settings tuned on clean synthetic pictures. It now uses the real-footage settings the one-camera path uses, scaled to the picture's width (`tv.calib.lineOptsFor`: ridge contrast 20; reach and minimum piece length in proportion, 6 and 14 px and 80 px at 4K). The tests on synthetic footage pass the synthetic settings explicitly: at 960 px wide the generator's far lines are under a pixel wide and fainter than the real-footage contrast, and with the real settings both synthetic Wide cameras came out 0.6 to 1.0 m off (the Linear ones were right to 1 cm). The real-footage settings have never seen a real picture from beside a court either: to be retuned on the Hero 7 clip.
