# Ball classifier weights (TV-DET-04)

Plain JSON read by `tv.detect.loadBallNet`; batch norm folded into each convolution (`vision/ml/export.py`). Numbers only: no pictures (Chris, 18 Nov).

| File | Trained on | Fixed test set (reviewed, one ball in play) | Status |
| --- | --- | --- | --- |
| `ballnet_v1.json` | The clay video only: drawn balls on 3D flights, plus its own proposals as "not a ball" | 28 of 34 found, 1 false spot (videos 1 and 2 unseen) | Shipped in v0.6.37 and v0.6.38 |
| `ballnet_v2.json` | Round 2: all three videos and the rest of the clay recording. Drawn balls plus 11,116 real balls mined by v1 (self-training, no hand labels). "Not a ball" examples leave out anything near a ball path or moving smoothly. | 30 of 34 found, 0 false spots; check set 27 of 36, 3 false (v1: 26, 4) | Shipped from v0.6.39 (the clay test re-run with it) |
| `ballnet_v4.json`, `ballnet_v4_pre.json` | Round 4: cuts scaled so the ball is 6 px across, brightness and motion only (no colour), light and dark swapped at random in training; `_pre` is the first pass (5,281 weights, threshold inside) that throws out plain non-balls before the classifier (`tv.detect.ballScores`) | 28 of 35 found, 2 false; check set 27 of 36, 3 false; 30 or 31 of 35 by the classifier alone in every light tried (round 2: 23 to 31) | In the repository as the any-camera model; not the default (round 2 is slightly ahead on these three videos as filmed) |
| `ballnet_v5.json` | Round 5: round 4 plus two colour-change pictures (how much a pixel's colour changed against each neighbour frame once the change of brightness is taken out: a shadow leaves nothing), trained also on stretches of the GoPro Hero 7 clip, the 3 Oct iPhone match and its SwingVision export, with mined and drawn shadows as "not a ball". Used with `ballnet_v4_pre.json`. | 30 of 35 found, 2 false; check set 28 of 36, 3 false; shadows among tracked spots on held-out new footage 2.5%, 1.9%, 0.3% (round 4: 12.8%, 12.1%, 6.2%). With light and dark swapped 13 of 35 (round 4: 31): a ball darker than the court is taken for a shadow. | The model for new cameras (19 Nov); not in the app |

Round 3 (18 Nov, not kept): round 2's data plus its own misses on unseen clay footage. Test set 31 of 35 with 1 false spot (round 2 on the same labels: 30 of 35, 0 false); video 2 gained a false spot, so it was not adopted.

Round 4 with colour as a hint (19 Nov, not kept): ties the no-colour version on every set and condition, so colour is not used.
