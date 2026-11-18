# Ball classifier training (TV-DET-04, 18 Nov)

The first models are trained here, in PyTorch on a CPU, before the PC exists (VISION-REQUIREMENTS TV-DET-04). The PC runs the same detector in MATLAB (`tv.detect.motionProposals`, `tv.detect.ballNet`, `tv.track.chains`), reading the weights `export.py` writes. Retraining moves to the PC later.

Nothing private is in this folder: the footage, the test-set labels and the trained weights stay outside the repository (`common.ROOT`).

| File | What it does |
| --- | --- |
| `common.py` | Paths, frame reading (ffmpeg, frame-exact like MATLAB), test-set labels and scoring |
| `proposals.py` | Python twin of `tv.detect.motionProposals` (same spots, checked frame by frame) |
| `gen_data.py` | Training examples: real proposals and balls drawn on 3D flights through the fitted camera |
| `model.py` | The classifier (about 63,000 weights) and its augmentation |
| `train.py` | Training; `heldout`, `vN` (one video) or `all` |
| `tracker.py` | Python twin of `tv.track.chains` and one ball in play |
| `detect_video.py`, `run_clips.py` | The detector over a stretch, or over every clip of a run (per-clip CSVs that `runSingle` reads) |
| `mine_runs.py`, `mine2.py` | Self-training: detector runs away from the test frames; confident smooth chains become real balls, and "not a ball" examples leave out anything near a chain or moving like a ball |
| `eval_windows.py`, `quickscore.py`, `ballscores.py`, `rescore.py` | Scores on the fixed test set |
| `export.py` | Weights for MATLAB (batch norm folded, plain JSON) plus a check case |
| `physics.py` | Camera projection and ball flight for drawing balls |
