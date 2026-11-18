# Ball classifier weights (TV-DET-04)

Plain JSON read by `tv.detect.loadBallNet`; batch norm folded into each convolution (`vision/ml/export.py`). Numbers only: no pictures (Chris, 18 Nov).

| File | Trained on | Fixed test set (reviewed, one ball in play) | Status |
| --- | --- | --- | --- |
| `ballnet_v1.json` | The clay video only: drawn balls on 3D flights, plus its own proposals as "not a ball" | 28 of 34 found, 1 false spot (videos 1 and 2 unseen) | Shipped in v0.6.37 and v0.6.38 |
| `ballnet_v2.json` | Round 2: all three videos and the rest of the clay recording. Drawn balls plus 11,116 real balls mined by v1 (self-training, no hand labels). "Not a ball" examples leave out anything near a ball path or moving smoothly. | 30 of 34 found, 0 false spots; check set 27 of 36, 3 false (v1: 26, 4) | Shipped from v0.6.39 |
