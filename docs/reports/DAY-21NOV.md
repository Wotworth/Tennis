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
| Video 1, 6.2 px | 0.23 | In flight, right beside the player's head as he turns: the three-frame picture the classifier sees is full of the head's movement |
| Clay video, 5.5 px | no spot | A ball lying still on the court, seen through the net |
| Clay video, 4.8 px | 0 | Another still ball, behind the net mesh |

**What the synthetic pictures leave out:** the size study draws a lone moving ball on a court (sometimes a line). Real misses come from **what touches or surrounds the ball**: the racquet at contact, and a moving body right next to it. The two clay ones are balls at rest; the detector looks for moving spots by design, so it doesn't find them, and they don't matter in play. Small or blurred balls are not the problem.
- **Effect on measurement:** small. At contact the flight fit runs the path to the racquet from both sides; a ball beside a player is found again a frame or two later.
- **Next (not started):** draw balls touching a racquet and right beside a moving figure in the training pictures, and count still balls apart in the test-set report (the labels themselves stay as they are).
