# Fixed ball test set (TV-DET-04, 18 Nov)

Numbers only, no pictures (Chris, 18 Nov): the frames themselves stay private. Every detector change is scored on this set, and it counts only if no video gets worse.

**Videos** (Chris's iPhone footage, kept private):
- **v1:** SwingVision export, 25 Apr 2025.
- **v2:** SwingVision export, 16 Apr 2025.
- **v3:** the unedited indoor clay recording of 10 Nov 2025, frame 0 at 36:00.

Frame numbers are 0-based (about 60 a second), as `tv.media.readFrames` counts them.

| File | Columns |
| --- | --- |
| `frames_vN.csv` | Sample number, frame, and the frame's whole-pixel shift against the empty court (`tv.calib.steady`) |
| `labels.csv` | Every ball seen in a sample frame (raw frame pixels) |
| `labels_moving.csv` | The same balls with their motion against frames 4 before and after; `diff` of 20 or more counts as a ball in play, below is ignored (still, held or unsure) |
| `labels_review.csv` | Second look (18 Nov): every spot either detector put where no label was, checked blind on five frames around it. `ball` adds a ball in play, `unsure` is ignored, `not` is a false spot |
| `baseline_colour_detector.csv` | The colour detector's tracked spots at each sample frame (17 Nov), for comparison |

Scoring (`vision/ml/common.py`): a ball is found when a spot lies within 10 px; any other spot not near an ignored ball is false.
