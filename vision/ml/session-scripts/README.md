# Session scripts for the footage tests (as run in the cloud session)

How the three iPhone videos were run and exported for the app: kept so a new session can repeat it. They are written for the session's own folders (`/home/user/private-footage`, an Octave copy of `vision/+tv`), so paths need changing elsewhere. No footage is here.

- `tvcfg.m`, `tvrun.m`, `tvexport.m`: settings, the one-camera run, and the export for the app (env `VID`, `DET`).
- `tvgeom.m`, `tvcam.m`, `tvpts.m`, `tvbg.m`, `tvsamples.m`, `tvtestset.m`: what the Python twin needs from the MATLAB run (ball size map, camera, frame times, empty court, test frames).
- `run_clips.py`: the Python twin of the detector over every clip of a run (`runSingle` reads its CSVs).
- `tvspots.m`, `tvb2.m`, `spotsheet.py`, `framesheet.py`: the blind spot check and the sample frames.
- `picks_clay_round2.m`: the clay test's sample frames, verdicts and notes.
- `orch_r4.sh`: round 4's steps in order.
- `overlay_rescan.py`, `overlay_cluster.py`, `overlay_delay.py`, `overlay_sheet.py`: around `../overlay.py` (the SwingVision overlay reader): scan a prepared export, group its words and digits for naming, compare the dots with the detector's tracks, and draw the 20-shot check sheet.
