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

A retry with a higher camera and a steeper aim is running. Whatever it gives, this is the first real GoPro picture the calibration has seen, and it did not cope. That needs fixing before the two-camera trials, and it is cheap to fix now.

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
- **The shadow is a new mistake, and round 4 made it possible.** Round 4 was trained to accept a dark ball on a pale court as readily as a pale ball on a dark one. In strong sun the ball's shadow is exactly that: a small dark thing moving like a ball. The earlier models would not have taken it.
- **Two of the 13 balls on the iPhone clip are not in play** (bounced before a serve, and in the server's hand). That is the tracker's "one ball in play" doing its job loosely, not a detector fault.
- These are precision figures only. I have not hand-labelled balls on these videos, so I can't yet say how many it misses.

## What to do about the shadow

A shadow darkens whatever is behind it without changing its colour. A ball brings its own colour. So the useful colour signal is not "what colour is this spot" (which changes with the light, and which round 4 showed adds nothing) but **"did the colour here change, or only the brightness?"** That holds under any light, because it compares the same patch of court with and without the thing on it.

I'd add that as two extra input pictures for the classifier and train it with shadows from these two videos as "not a ball" examples. It is the robust use of colour you described.

## Speed on these

One CPU core, with other jobs running beside it: 0.7 to 0.8 s a frame on the iPhone clip, 1.4 s a frame on the GoPro at 2.7K. Finding the moving spots is two thirds of that.
