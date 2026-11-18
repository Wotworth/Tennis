# Check set (round 2, 18 Nov)

Kept apart from the fixed test set: it is used to set the tracker and compare models during training. The test set gives the final verdict.

**What's in it:** 40 frames, none within 2 s of a frame used for training or within 4 s of a test frame.
- v 4 is the whole clay recording, with frame 0 at its start. 12 frames come from the warm-up (the first 5 minutes) and 12 from after 51:00.
- v 1 and v 2: 8 frames each.

**How it was labelled:** every spot either model (the shipped one and the self-trained one) scored above 0.3, plus each model's tracked ball, was checked on five frames around it without knowing its source. Each spot is marked `ball`, `unsure` (ignored: held, rolling or unclear) or `not`. Balls neither model found are not labelled, so this set compares models; it doesn't measure true recall.
