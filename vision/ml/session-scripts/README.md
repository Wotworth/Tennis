# Session scripts for the footage tests (as run in the cloud session)

How the three iPhone videos were run and exported for the app: kept so a new session can repeat it. They are written for the session's own folders (`/home/user/private-footage`, an Octave copy of `vision/+tv`), so paths need changing elsewhere. No footage is here.

- `tvcfg.m`, `tvrun.m`, `tvexport.m`: settings, the one-camera run, and the export for the app (env `VID`, `DET`).
- `tvgeom.m`, `tvcam.m`, `tvpts.m`, `tvbg.m`, `tvsamples.m`, `tvtestset.m`: what the Python twin needs from the MATLAB run (ball size map, camera, frame times, empty court, test frames).
- `run_clips.py`: the Python twin of the detector over every clip of a run (`runSingle` reads its CSVs).
- `tvspots.m`, `tvb2.m`, `spotsheet.py`, `framesheet.py`: the blind spot check and the sample frames.
- `picks_clay_round2.m`: the clay test's sample frames, verdicts and notes.
- `orch_r4.sh`: round 4's steps in order.
- `overlay_rescan.py`, `overlay_cluster.py`, `overlay_delay.py`, `overlay_sheet.py`: around `../overlay.py` (the SwingVision overlay reader): scan a prepared export, group its words and digits for naming, compare the dots with the detector's tracks, and draw the 20-shot check sheet.

## A new SwingVision export, step by step

As done for the 16 Apr and 25 Apr exports (docs/reports/SWINGVISION-SESSIONS-1.md). One video at a time: the session has about 5 GB of disk, so delete each video once its numbers are out. `N` is the next free video number.

1. Download it to `/home/user/private-footage/sN/` (never into the repository).
2. Overlay: `overlay.py prep VIDEO /home/user/private-footage/overlay/vN`, then `overlay.py read …/vN`. Check the summary line: every label read, no "?".
3. Camera: add the file to `tvcfg.m`'s `files`, run `VID=N CLIPS=prep octave tvrun.m` (court lines to camera; `runN/stages/calib.mat`), then `tvgeom.m`, `tvcam.m`, `tvpts.m` and `tvbg.m` with their loops set to `N` (ball size map, camera, frame times, empty court for the Python twin).
4. Add `N` to `VIDEO` and `OVERLAYS` in `common.py`.
5. Detector: `STEP=1 WORKERS=4 MODEL_IN=grey WEIGHTS=…/net_r4.pt PRE=…/net_pre4.pt detect_points.py N OVERLAY_DIR …/ml/pts_r4` (about 0.5 to 1 s a frame per core).
6. `session_report.py N OVERLAY_DIR …/ml/pts_r4` (the scores) and `mine_weak.py N OVERLAY_DIR …/ml/pts_r4 OUT.npz` (the weak labels). A court kept for testing gets the scores only: its weak labels are never trained on.
