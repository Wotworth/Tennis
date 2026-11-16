# Tennis Vision System: spec

Chris's spec of 16 Nov 2026 ("Tennis Vision System — Setup, Shopping List & Claude Code Requirements"). This file is the source of truth for the vision work, as `REQUIREMENTS.md` is for the app; its section 0 rules apply here too.

Two things were changed from the original:
- One sentence naming Chris's employer was removed, because the repository is public.
- Chris's answers of 15 Nov are applied in place. They are marked **[15 Nov]** and listed in section A.

The parts of the original that are reasoning rather than requirements are kept in short form in section B: feasibility, the SwingVision comparison, the shopping list, the suggested extra features and the sources.

## A. Chris's answers (15 Nov 2026)

1. **Phase names.** Phases are TV-PH-0 to TV-PH-5, so they don't clash with the app's PH-0 to PH-5.
2. **Testing.** The MATLAB code is tested on GitHub. MathWorks' GitHub actions run MATLAB free for public repositories. Sessions on the closet PC come later, for real footage.
3. **Privacy.** The repository stays public. Home location, court coordinates, camera serials and tokens live only in the PC's `config/tennisvision.json`, which is never committed. Tokens are kept in Windows Credential Manager.
4. **Health data stays on the phone.** Nothing from Health Connect is uploaded, not even summaries. The app computes every heart-rate figure and trend itself (TV-HC-02, TV-HC-04).
5. **One more host for the app.** From TV-PH-4, the app may reach exactly one more host besides api.anthropic.com: the Worker. Videos are stored in R2. This settles the open question "video in the cloud or streamed from the PC". It is an exception to the app spec's section 0 (3), "no cloud sync", for vision sessions only.
6. **Placement check before buying.** TV-CAL-04 runs first on GoPro's published MISSION 1 lens figures (Linear, Wide and SuperView), and its results are marked provisional until a lens is calibrated. The 112–156° figures on the box are diagonal angles. The horizontal angles are 100° (Linear) and 128° (Wide).
7. **Fence distances vary.** The placement check outputs a lookup table for side-fence distances from 2 to 10 m. Each row gives the recommended mount spot, the frame (16:9 or 4:3 Open Gate), the expected far-corner bounce error, and when to use a light stand instead.
8. **Opponents' stats.** Only Chris's stats are shown; other players are labelled Player A, Player B, and so on. Asking regular partners whether they mind being recorded is Chris's job.
9. **Active calories.** TV-HC-01 reads active calories. That needs one new phone permission, READ_ACTIVE_CALORIES_BURNED, added to `ci/allowed-permissions.txt` in TV-PH-4.

10. **Camera layouts (15 Nov).** Chris uses one of two, depending on the court:
    - (1) both cameras on one side, level with each baseline (side fence on outer courts, light stands if needed);
    - (2) the back-fence corners at both ends, on one side (typical on middle courts).

    He checks coverage with the Quik live view and does not measure fence distances. Neither layout is hard-coded. Calibration runs from the court lines every session, and the court's half-turn symmetry is resolved by the pose combination where both cameras agree on the ball and the players. The stereo crossing angle over the court goes into session.json; zones below the usable angle are named in the ntfy message.
11. **Courts in the app (15 Nov).** The app works offline and asks for no location permission.
    - **Adding a court:** a typed name, the layout (1 or 2), the lens mode that worked (16:9 or 4:3 Open Gate), an indoor switch, and an optional photo of the camera mounts.
    - **Picking a court:** shows its setup. A court picked before playing labels the next vision session that overlaps that time.
    - **Indoor courts:** the app sends only an indoor flag for that session (no name, no photo). The PC reruns from the physics stage with indoor settings (wind 0, indoor temperature and humidity), like an identity answer.
    - Names and photos stay on the phone, and never go to the PC or the repository.

12. **Singles only (15 Nov).** Chris plays singles only. TV-PLY-08's doubles support (3–4 players, Partner / Opponent labels) is not built; line calls use the singles lines.

13. **Detector improvement loop (15 Nov).** Chris's input is quick taps in the app. All app feedback takes the identity answers' path: the app posts, the PC pulls, and the Worker computes nothing.
    - **Ball check (hand-labelled test set).**
      - The PC picks frames spread across days and light, favouring frames the detector was unsure about, and uploads ~256 × 256 crops around the predicted ball.
      - The app shows one at a time: ✓ (marker on the ball), a tap on the true position, or "no ball". Batches of about 20, sized for phone and tablet.
      - About 300 frames make the first set; small batches follow as conditions change (new courts, indoor, night).
    - **"This looks wrong"** on each shot card, with a reason: wrong speed, wrong in/out, not my shot, not a real shot. Logged for review and tuning.
    - **"Missed a shot here"** in rally videos records the time. The PC re-examines that window and adds any confirmed shot as a training example.
    - **Automatic retraining.**
      - When: overnight when idle, after 20,000 new auto-labelled frames or monthly.
      - Auto-labels: only detections both cameras agree on that fit a physically possible flight, plus physics-predicted positions in gaps. Frames where a player or the net hides the ball are excluded.
      - Promotion: only if the new model beats the current one on the hand-labelled set, with recall and precision both no worse; otherwise the old one stays and the reason is logged.
      - Auto-labels never enter the test set.
    - **Reporting:** the weekly ntfy message carries each retraining result (old vs new recall and precision) and the count of open "looks wrong" flags.
    - **Tile and notifications:** the launcher tile may show "N frames to check" at the lowest priority. The app sends no notifications.
14. **Spin types (15 Nov).** rpm alone does not tell topspin from slice. Spin is always shown with its kind (topspin, slice, flat) and the split between topspin/backspin and sidespin, and spin statistics are kept per kind.
15. **Opponents (15 Nov).**
    - **The prompt:** after a session is processed, the app asks "Who did you play?" with one tap. Saved names come most recent first, then "add new" and "skip / unknown".
    - **What a choice does:** the name is attached to the session and to every shot by the non-Chris player.
    - **The list:** add, rename, merge duplicates, delete. Renaming or merging updates all past sessions.
    - **Suggestion:** the opponent from the last session at the same court is the default, but never assigned automatically.
    - **Doubles:** not in v1 (one opponent). A doubles option may come later.
    - **Opponent pages:** each opponent has their sessions, head-to-head history and their shot stats. Their stats stay behind the per-session "opponent's stats" toggle.
    - **Where names live:** only in the cloud database; never in Git, test fixtures or logs.

## 1. Scope, architecture, conventions

Three components, built in phases (section 7):
1. **Vision pipeline** (`vision/`, MATLAB) on the closet PC: ingest, calibration, sync, rally cutting, ball tracking, 3D reconstruction, physics fitting, metrics, plots, upload.
2. **Cloud API** (`cloud/`): Cloudflare Worker plus R2 and D1.
3. **Tennis app changes:** sessions UI, 2D and 3D views, trends, Health Connect merge.

Out of scope for v1: racquet and swing tracking, body-pose biomechanics, automatic scoring.

### Languages and dependencies
- TV-ARCH-01 All analysis, orchestration, plotting and uploading shall be MATLAB (R2026b or later). The code must be readable by a MATLAB engineer: packages (`+tv`), clear names, comments on the physics.
- TV-ARCH-02 MATLAB may call FFmpeg/ffprobe via `system()` for decoding, cutting and encoding video. No Python. No compiled MEX unless profiling proves it necessary.
- TV-ARCH-03 Allowed MATLAB products:
  - the Home Suite: Image Processing, Deep Learning, Optimization, Parallel Computing, Signal Processing, Statistics and Machine Learning, Curve Fitting;
  - Computer Vision Toolbox;
  - free support packages.
  - Not available on Home, so not to be used: Sensor Fusion and Tracking Toolbox, MATLAB Coder, MATLAB Compiler.
- TV-ARCH-04 One-time Windows setup (Task Scheduler, power settings, AutoPlay) may be a PowerShell script that CC runs and explains. Nothing else outside MATLAB on the PC.
- TV-ARCH-05 The Worker shall be TypeScript. The app keeps its existing stack and Metro-style design.

### Coordinate frame and units
- TV-ARCH-10 **[16 Nov]** Court frame, set by where the cameras are, never by their serial numbers or roles: origin at the centre of the net at ground level, and right-handed:
  - y runs across the court, positive away from the side both cameras are on (both layouts put them on one side);
  - z points up;
  - x = y × z: along the court's length, toward the end on your right as you stand on the cameras' side facing the court.
  - Which camera is at which end is reported in `session.json` (`cam2AtLowerX`); swapping them changes nothing else. A test runs the cameras swapped.
- TV-ARCH-11 SI units internally (m, s, kg, rad). The app displays mph, ft, rpm and °F by default, switchable.
- TV-ARCH-12 All times are UTC, stored as datetime with time zone, accurate to at least 0.1 ms internally.

### Constants (ITF standard court and ball)
| Constant | Value |
|---|---|
| Court length | 23.77 m |
| Doubles / singles width | 10.97 m / 8.23 m |
| Service line from net | 6.40 m |
| Net height at centre / at posts | 0.914 m / 1.07 m |
| Net posts outside doubles sideline | 0.914 m |
| Ball diameter | 6.54–6.86 cm (use 6.70 cm) |
| Ball mass | 56.0–59.4 g (use 57.7 g) |

### Configuration, logging, versioning
- TV-ARCH-20 One config file, `config/tennisvision.json`. It holds:
  - camera serials and roles;
  - home ZIP code and court coordinates;
  - folder paths and retention days;
  - upload endpoint and alert topic;
  - thresholds.
  - No secrets in Git: tokens live in Windows Credential Manager or an ignored file.
  - **[15 Nov]** The whole file is ignored. Only `config/tennisvision.example.json` is committed.
- TV-ARCH-21 Each stage writes its outputs plus a `manifest.json`: input file hashes, code Git SHA, parameters, start and end time, status. A stage is skipped when its manifest matches, so rerunning with new code reprocesses only what changed.
- TV-ARCH-22 Plain-text logs per session and per day under `logs/`, with timestamps and stage names.
- TV-ARCH-23 Never lose footage. No step may delete or overwrite a source video unless a verified copy exists (TV-ING-05).

### Repository layout
```
tennis/
  vision/
    +tv/       MATLAB package: ingest, calib, sync, detect, track, recon, physics, metrics, viz, upload
    config/
    tests/     matlab.unittest + synthetic-data tests
    tools/     calibration GUI, reprocess, diagnostics
    setup/     one-time PowerShell setup script
  cloud/       Worker (TypeScript), D1 schema, R2 config
  app/         existing Android app
```

## 2. Ingest and session assembly

The only user action is inserting cards. The watcher must therefore cope with any order, timing or interruption, and must never lose a file.

### Watcher
- TV-ING-01 `tv.watch` starts at log-on and polls every 5 s for new volumes containing a GoPro DCIM folder. The folder pattern is configurable.
- TV-ING-02 Identify the camera by its serial number from MP4 metadata, never by drive letter or insertion order. Map serial to role (cam1, cam2) in config. An unknown serial triggers an alert and is imported as a new camera.
- TV-ING-03 Cards may arrive together, minutes apart, or one at a time across days. Each card is imported on its own; pairing happens later (TV-ING-20).

### Copy, verify, wipe
- TV-ING-04 Copy every MP4, LRV and THM file to a staging folder on the NVMe drive, then move it to the archive at `D:\TennisVision\raw\<UTC date>\<serial>\`.
  - Copy both cards in parallel.
  - Once a card is wiped, the staging copy is the only copy. Hash the archive copy on D: and confirm it matches before deleting the staging copy.
  - Show progress on the status light, and post "Import started" with the file count and size.
- TV-ING-05 Compute each file's SHA-256 while copying, so each card is read only once. Then hash the copy on the NVMe drive and compare. Store the hashes in the manifest.
- TV-ING-06 After verification, delete the imported files from the card (config `wipe_card_after_import`, default true).
  - Only delete files that were verified, never the folder structure.
  - Then flush and dismount the volume, set the light to green, and post "Cards safe to remove".
- TV-ING-07 If a card is pulled mid-copy, keep partial files marked incomplete, and resume when the card returns. Never wipe a partly imported card.
- TV-ING-08 Import time target: 2 × 216 GB (2 h at 240 Mbps) in ≤ 45 min, copied in parallel. The limit is the UHS-I card, about 90 MB/s.
- TV-ING-09 Check free space before copying. Below 15% free, run the retention clean-up first (TV-OPS-03). Refuse and alert only if that cannot free enough space.

### Metadata
- TV-ING-10 For each recording, read with ffprobe: codec, resolution, nominal frame rate, and per-frame presentation timestamps (PTS). Never assume a constant frame interval; 120 fps may actually be 119.88.
- TV-ING-11 Group chapter files into one recording with a continuous timeline. Do not re-encode or concatenate the raw files.
- TV-ING-12 Extract the GPMF telemetry track with FFmpeg and parse its key-length-value format in MATLAB. Read:
  - the GPS fix: latitude, longitude, altitude and GPS UTC time;
  - the timecode;
  - camera settings per frame: shutter, ISO and white balance, where present;
  - the accelerometer and gyro, used to detect a bumped camera.
- TV-ING-13 Convert each frame's PTS to UTC using the GPS time where there is a fix, else the camera clock. Record which source was used.

### Calibration clips
- TV-ING-14 A recording in which a checkerboard is detected in ≥ 30% of sampled frames is a calibration clip. Route it to intrinsic calibration (TV-CAL-01), not to session processing.

### Session pairing
- TV-ING-20 A session is the set of cam1 and cam2 recordings whose UTC time ranges overlap. Create `sessions/<UTC start>_<court>/session.json` listing them.
- TV-ING-21 If only one camera's footage arrives within 24 h, process in single-camera mode and post an alert. Single-camera mode produces the rally reel and the 2D bounce map only, marked "reduced".
- TV-ING-22 Identify the court by GPS: the nearest saved court within 150 m.
  - Without a GPS fix (usually indoors), match the session's background frame against saved courts (TV-IND-02).
  - An unknown location creates a new court entry and triggers fresh court calibration.

## 3. Calibration and time sync

A ball at 30 m/s moves 3 cm per millisecond, so a 1 ms timing error between the cameras is a 3 cm position error.

### Lens (intrinsic) calibration: once per camera and mode
- TV-CAL-01 From calibration clips, sample about 60 well-spread checkerboard views.
  - Fit both the fisheye model (`estimateFisheyeParameters`) and the standard model with three radial terms (`estimateCameraParameters`).
  - Keep the one with the lower reprojection error. Target RMS ≤ 0.5 px.
- TV-CAL-02 Store the result as `calib/intrinsics_<serial>_<mode>.mat`, with a PDF report showing coverage and residuals. A session recorded in a mode with no calibration triggers an alert, and the session waits.

### Camera placement check: TV-PH-0, before mounting
- TV-CAL-03 Coverage:
  - Both cameras must see the ground of the play volume (the court plus 3 m behind each baseline) and everything up to 4 m high.
  - Above 4 m (high lobs), one camera is enough; the physics fit carries the path through.
  - Requiring both cameras up to 8 m is impossible near each camera, because a 16:9 frame covers only about 9/16 of its horizontal angle vertically.
- TV-CAL-04 The placement check:
  - Using the lens model, compute coverage and the stereo crossing angle over the play volume for candidate positions along one side fence: service-line vs baseline extensions, 3–5 m outside the doubles sideline, 2.5–3.5 m high.
  - Report the minimum crossing angle and the expected bounce error at the far corners, and recommend positions before Chris mounts anything.
  - Confirm the camera's field of view in each trial mode, including 4:3 Open Gate (the full sensor, about a third more vertical view).
  - If no side fence is within 5 m of the doubles sideline (common where courts sit side by side), also evaluate light stands at those spots and corner positions on the back fence.
  - **[15 Nov]** Use GoPro's published MISSION 1 lens figures, marked provisional until a lens is calibrated.
  - **[15 Nov]** Output a lookup table for side-fence distances from 2 to 10 m: recommended mount spot, frame (16:9 or 4:3 Open Gate), expected far-corner bounce error, and when to use a light stand instead.
  - **[16 Nov]** Also evaluate layout 2 (back-fence corners at both ends, same side) for back-fence distances of 4–7 m behind the baseline and side distances of 2–5 m, in every lens mode: smallest crossing angle and where, far-corner range, ball size in pixels, and the expected bounce error.

### Camera pose (extrinsic) calibration: every session, automatic
- TV-CAL-10 Build a background frame: the median of about 200 frames spread over a quiet minute. Detect the white court lines (threshold, thin, Hough), then fit the known court model by matching line intersections.
- TV-CAL-11 Solve the camera pose (`estworldpose`), then refine it by least squares on the distance of every detected line pixel to its projected model line. Lines are more robust than corners.
- TV-CAL-12 Add points off the ground to improve conditioning: the tops of the net posts (1.07 m) and the net tape at the centre (0.914 m).
- TV-CAL-13 Target: line reprojection RMS ≤ 1.0 px per camera. Report it in `session.json`.
- TV-CAL-14 Re-solve the pose every 5 min of footage, and whenever the gyro shows a bump. If the camera moved more than 0.05°, split the session and use a pose per segment.
- TV-CAL-15 If automatic calibration fails, post an alert. Provide `tools/clickCourt.m`, a GUI used over Remote Desktop to click at least six court points, and resume from there.

### Time sync between the cameras
The cameras are not genlocked, so pairing frames by index is wrong. The model maps camera 2's clock onto camera 1's with an offset and a slow drift. It also accounts for rolling shutter: each row of the image is exposed slightly later than the row above.

t₁ = t₂ + Δ + ε (t₂ − t_ref);  t_pixel = t_frame + (v/H) τᵣ

- Δ is the offset.
- ε is the clock-rate difference. Crystal clocks differ by tens of ppm, which is tens of ms per hour.
- v is the pixel row and H the image height.
- τᵣ is the sensor readout time.

- TV-SYNC-01 Coarse: the timecode tracks, or GPS UTC from GPMF. Expected within a frame or two.
- TV-SYNC-02 Medium:
  - Cross-correlate the audio envelopes, then match sharp transients (racquet hits, bounces) between cameras.
  - Correct each transient for the sound's travel time from its 3D source, using c = 331.3 √(1 + T/273.15) m/s, with T in °C from the weather data.
  - Iterate once 3D positions exist.
- TV-SYNC-03 Fine (the final answer): estimate Δ, ε and τᵣ for each camera by minimising the total reprojection error of all fitted ball trajectories. A wrong offset shows up directly as a large stereo residual on fast shots.
- TV-SYNC-04 Target: residual timing error ≤ 0.5 ms. Report Δ, ε, τᵣ and their uncertainties in `session.json`.
- TV-SYNC-06 **[16 Nov]** Measure each camera's readout time τᵣ once per mode, outside play, and give the session fit a tight prior from it:
  - Record about 10 s of a plain wall lit by a mains-powered lamp that flickers (most LED and fluorescent lamps flicker at twice the mains frequency, 120 Hz in the US), at the session shutter speed.
  - Rolling shutter turns the flicker into horizontal bands. The band spacing in rows gives τᵣ = H / (rows per band) / 120 Hz, to well under 1%. `tools/readoutFromFlicker.m` measures it from the clip, and the PC stores it per camera serial and mode.
  - Ball flights alone do not pin τᵣ down: within one flight the ball's image row changes almost linearly with time, so a readout error looks like a small stretch of time that the flight's own speed absorbs. The synthetic test settled 2.5 ms off on one camera.
- TV-SYNC-05 Never triangulate by pairing frames. Fit the 3D trajectory model directly to each camera's 2D detections at that camera's own corrected pixel times (TV-REC-01).

## 4. Rallies, ball detection, tracking, 3D

### Rally segmentation
- TV-RAL-01 First pass on the GoPro low-resolution proxy files (LRV) or 1/4-scale frames, plus audio. Score activity from:
  - fast ball candidates inside the court volume;
  - racquet-hit sounds;
  - hit cadence (hits 0.8–2.5 s apart).
- TV-RAL-02 Rally boundaries:
  - A rally starts 1.5 s before the first serve toss or first hit.
  - It ends 2 s after the last bounce or dead ball.
  - Merge rallies less than 4 s apart.
  - Never clip a shot; when in doubt, keep footage.
- TV-RAL-03 Ball pickup, walking and talking are removed. Target: ≥ 98% of rallies captured; ≤ 10% of the kept footage is dead time.
- TV-RAL-04 Produce `reel_1080p.mp4` and one clip per rally.
  - The reel has rallies only, from the camera with the better view of the near player; split screen is optional.
  - Encode for phone playback with FFmpeg's GPU encoder.

### Ball detection
- TV-DET-01 Version 1, classical:
  - background subtraction plus differences across three consecutive frames;
  - an HSV colour gate for optic yellow;
  - a blob-size gate, using the expected ball size in pixels at each image position (from the calibration and the 6.7 cm diameter).
  - Normalise each frame's brightness before differencing, so light flicker doesn't look like motion.
- TV-DET-02 Mask everything outside the projected court volume: the court plus a 4 m margin, up to 8 m high. Treat stationary yellow objects (balls lying on court, the ball basket) as background.
- TV-DET-03 Accept elongated blobs consistent with motion blur along the expected direction.
- TV-DET-04 Version 2, learned: a TrackNet-style heat-map detector, trained with Deep Learning Toolbox on the GPU. Its input is three consecutive frames; its output is a ball-probability map.
- TV-DET-05 Training labels:
  - Most come free: v1 detections that survive the stereo and physics checks become labels.
  - Corrections are made in Video Labeler.
  - Keep a held-out test set from different days and light conditions.
  - **[16 Nov]** Both sets are kept as full three-frame sets, forever (TV-OPS-07).
- TV-DET-06 Targets after tracking: ≥ 95% of in-play frames detected; ≥ 98% of accepted detections correct.

### 2D tracking per camera
- TV-TRK-01 Track candidates with a Kalman filter on a constant-acceleration model, with gating. Bridge up to 10 missed frames (behind a player or the net post).
- TV-TRK-02 Split tracks into flight segments at events: hit, bounce, net contact, leaving the view.
- TV-TRK-03 Handle several balls in view. Each gets its own track; non-play balls are labelled and ignored.

### 3D reconstruction
- TV-REC-01 For each flight segment, fit the physics model of section 5 directly to both cameras' 2D detections at their corrected pixel times.
  - Minimise reprojection error with a robust loss (`lsqnonlin`).
  - Initialise from linear triangulation of time-interpolated 2D tracks.
- TV-REC-02 Match tracks between cameras by epipolar consistency and by timing.
- TV-REC-03 Output 3D positions sampled at 200 Hz with covariance, plus the fit's RMS reprojection error. Reject or flag fits above 2 px RMS.

### Events
- TV-EVT-01 Hit: a sudden change in velocity near a player. Attribute the hitter to a tracked player (TV-PLY-09), never by side of the net alone.
- TV-EVT-02 Bounce: solve jointly for the point where the incoming and outgoing segments meet at ball-centre height 3.35 cm.
- TV-EVT-03 Net: the ball's bottom (centre − 3.35 cm) crosses x = 0 below the net's height at that y, or the ball decelerates abruptly near it.
  - The net sags linearly from 1.07 m at the posts to 0.914 m at the centre.
  - A centre passing within 3.35 cm of the tape means the ball touched it.
- TV-EVT-04 In or out:
  - Compare the bounce point with the singles lines (the service box on serves), using the bounce uncertainty. **[16 Nov]** Singles only: no doubles lines in v1.
  - Report in, out, or "too close" when within 2σ.
- TV-EVT-05 Serve: a slow vertical toss above a player behind the baseline, then a hit near the toss apex.

### Player tracking and identity
- TV-PLY-01 Detect people throughout the session with the pretrained person detector:
  - On the LRV proxies at about 10 fps between rallies, and inside rally windows at about 30 fps on frames scaled to about 1080p. Interpolate positions to the hit times.
  - Place each person on court where their feet meet the ground: extend the sight line through the bottom centre of their box down to z = 0.
  - Cross-check the two cameras' estimates; one camera is enough when the other's view is blocked.
  - While a player is in the air, hold their last ground position.
- TV-PLY-02 Give each person one track ID for the whole session, linking detections by 3D court position and appearance (clothing colour histogram).
- TV-PLY-03 Identity anchor: Chris wears a solid magenta cap for at least the first few minutes. Detect the cap as a magenta blob at the top of a person's box in either camera. The track that shows the cap is Chris.
- TV-PLY-04 Keeping Chris's identity:
  - Once his track is known, learn his clothing colours and standing height for the session, and use them when the cap is hidden, removed or out of view.
  - A hat swap is the same person: update the head part of the appearance model.
  - If he leaves both views and returns, re-identify him from clothing and height. If that is ambiguous, use TV-PLY-07.
- TV-PLY-05 Height cue: estimate each player's standing height from stereo, between points. Chris is 1.89 m, stored in config. This is supporting evidence only.
- TV-PLY-06 The cap's magenta must fall outside the ball detector's colour gate. Test the two against each other.
- TV-PLY-07 Identity confidence and the "Which one is you?" question:
  - **Trigger.** Compute identity confidence per track segment. If any segment containing hits falls below 0.9, the app asks once, "Which one is you?", with one thumbnail per player. One tap relabels every affected shot. Never more than one question per session.
  - **On the PC.** It finishes processing anyway, labels the uncertain tracks "Player A / Player B", and uploads one thumbnail per player.
  - **In the app.** The question shows when the session is opened, and the tile shows "1 question"; there is no notification. The answer goes to `POST /sessions/{id}/identity`.
  - **Applying the answer.** The PC checks `GET /identity/pending` every 5 minutes, reruns only the metrics stage, and re-uploads.
  - **Until answered.** The app shows stats per player and keeps the session out of trends.
  - **Several uncertain stretches.** Ask on one screen, with one row of thumbnails per stretch.
- TV-PLY-08 **[16 Nov] Cut from v1:** singles only, two players (Chris and one opponent).
- TV-PLY-09 The hitter is the tracked player nearest the ball at the moment of the hit, within 2.5 m. On a serve, it is the player under the toss.
- TV-PLY-10 Reject yellow blobs attached to a tracked person that never follow a ballistic path. A serve toss is accepted once it leaves the head and rises and falls under gravity.

## 5. Physics, air density, spin, metrics

m v̇ = m g − ½ ρ A C_D |u| u + ½ ρ A C_L |u|² (ω̂ × û),  u = v − w

- u is the ball's velocity relative to the air, and w the wind.
- A is the ball's cross-section, and ω̂ the spin axis.
- C_D and C_L are the drag and lift coefficients.
- Topspin pushes down; slice pushes up. For a 25 m/s groundstroke, drag alone decelerates the ball about 11.6 m/s², more than gravity.

- TV-PHY-01 Integrate with fixed-step RK4 at 1 ms. Check against ode45 in tests.
- TV-PHY-02 Per flight segment, fit:
  - start position (3) and start velocity (3);
  - the Magnus push as a 2-vector perpendicular to the velocity through the air (1 angle around the flight path, 1 magnitude);
  - C_D (1, with a prior).
  - Spin about the direction of travel produces no push and is not fitted.
  - Spin is assumed constant within a segment; the bounce starts a new segment with new spin.
- TV-PHY-03 Per session, fit jointly across all shots:
  - the wind: horizontal, 2 parameters per 15-minute window, with a penalty on large changes between windows. A window with too few shots falls back to the prior.
  - the session's mean C_D.
- TV-PHY-04 Priors:
  - C_D per shot ~ N(session C_D, 0.024²), the spread Cross & Lindsey measured in flight (mean 0.507).
  - Wind: half the 10 m forecast wind, standard deviation 2 m/s.
- TV-PHY-05 Report the session C_D as the ball-wear indicator.

### Air density
- TV-AIR-01 Fetch hourly weather from Open-Meteo: temperature_2m, relative_humidity_2m, surface_pressure, wind_speed_10m, wind_direction_10m and wind_gusts_10m.
  - Use surface pressure, not sea-level pressure.
  - Open-Meteo needs no key for non-commercial use, and requires CC BY 4.0 attribution.
- TV-AIR-02 Location: the GPS from GPMF; failing that, the court's saved coordinates, then the home ZIP's coordinates. Cache responses. Interpolate to each rally's time.
- TV-AIR-03 Moist-air density: ρ = (p − p_v)/(R_d T) + p_v/(R_v T), with p_v = φ · 610.94 · exp(17.625 T_C/(T_C + 243.04)) Pa.
  - R_d = 287.05 and R_v = 461.5 J/(kg·K).
  - φ is the relative humidity, 0–1.
  - Store ρ in `session.json`.

### Indoor courts
- TV-IND-01 Each saved court has an indoor flag. Indoors:
  - Wind is fixed at 0 (not fitted).
  - Temperature and humidity come from configurable indoor defaults.
  - Pressure still comes from Open-Meteo.
- TV-IND-02 With no GPS fix, identify the court by matching the background frame against saved courts. A new court first seen without a GPS fix is marked indoor.
- TV-IND-03 Indoor light (300–750 lux) needs about 1/250–1/600 s at ISO 1600, which smears a 30 m/s ball 5–12 cm. The detector must accept that longer blur indoors.

### Spin
- TV-SPN-01 Spin effect (primary): re-simulate each shot from the same start with C_L = 0. Report how much shorter (or longer) the real bounce landed, and the change in net clearance.
- TV-SPN-02 Spin axis: report the topspin/backspin and sidespin parts of the Magnus push separately.
- TV-SPN-03 Spin rate (secondary): convert C_L to rpm through S = rω/|u|, using a configurable C_L(S) table.
  - Initial table: C_L ≈ 0.03 + 0.51 S for 0.14 ≤ S ≤ 0.53. Replace it with a proper fit to Cross & Lindsey.
  - The rpm counts only spin about axes perpendicular to the flight path.
- TV-SPN-04 Always report rpm with its uncertainty: the fit uncertainty combined with about ±25% for the C_L model. Below S ≈ 0.1, report "flat / low spin" with no rpm.

### Shot metrics
| Metric | Definition |
|---|---|
| Hitter, shot type | From events; serve / forehand / backhand / volley / overhead (hitter in TV-PH-2, type in TV-PH-5) |
| Contact point | 3D position at the hit |
| Speed at contact, at the bounce, after the bounce | Magnitude of the fitted velocity |
| Launch angle, direction | Elevation and azimuth of the velocity at contact |
| Net clearance | Height of the ball's bottom above the net at the crossing point, using the sag |
| Apex height, flight time | From the fitted path |
| Bounce location, depth | Bounce x, y; distance inside the baseline |
| In / out / too close, margin | TV-EVT-04 |
| Spin effect | TV-SPN-01, in m |
| Spin axis, spin rate | TV-SPN-02 and 03, rpm ± uncertainty |
| Bounce kick | Rebound angle; speed ratio after/before |
| Fit quality | RMS reprojection error, confidence 0–1 |

### Session and trend metrics
- TV-MET-01 Per rally: shot count, duration, how it ended (net, out, unforced, winner), fastest shot.
- TV-MET-02 Per session, by shot type:
  - count;
  - median and spread of speed, spin effect, rpm, net clearance and depth;
  - in %;
  - the landing-spot dispersion ellipse (1σ area in m²);
  - first-serve speed and in %;
  - metrics over time within the session (fatigue curve);
  - air density, wind and session C_D.
- TV-MET-03 Trends across sessions for all of the above. Each is linked to the racquet, string, tension and days since restring.

## 6. Outputs, upload, app, Health Connect

- TV-OUT-01 `session.json`: cameras, calibration and sync quality, weather, air density, wind, session C_D, code version, processing times.
- TV-OUT-02 `shots.json` and `shots.csv`: one record per shot with every metric in section 5.
- TV-OUT-03 `trajectories.json` (gzip): 3D samples at 200 Hz per shot, plus the no-spin comparison path.
- TV-OUT-04 `rallies.json`, `reel_1080p.mp4`, one clip per rally, and a tracer version of each clip.
- TV-OUT-05 PNGs via `exportgraphics`, in one consistent colour scheme:
  - bounce maps by shot type;
  - a 3D plot per rally;
  - a side view per shot comparing the real and no-spin paths;
  - speed and spin histograms.
- TV-UP-01 Upload from MATLAB (`matlab.net.http`) with a bearer token.
  - Videos and trajectories go to R2 through upload links issued by the Worker (multipart above 100 MB).
  - Session, rally and shot rows go to D1 through the Worker.
  - Plan on the Workers Paid plan.
- TV-UP-02 Uploads are idempotent (keyed by session ID and file hash), resumable, and retried with growing back-off. A session shows in the app only once its upload is complete.
- TV-UP-03 On completion, the session appears in the app and on the launcher tile. The app sends no notifications; PC status goes through ntfy.
- TV-API-01 Endpoints:
  - `POST /sessions`, `POST /sessions/{id}/upload-url`, `PUT /sessions/{id}/data`;
  - `GET /sessions`, `GET /sessions/{id}`, `GET /sessions/{id}/shots`;
  - `GET /trends?metric=&shotType=&from=&to=`.
- TV-API-02 D1 tables: sessions, rallies, shots, courts, cameras, processing_runs. Index shots by session, hitter and shot type.
- TV-API-03 Separate write (PC) and read (app) tokens; no public access to R2.
- TV-API-04 Identity answers: `POST /sessions/{id}/identity` and `GET /identity/pending`. The Worker stores answers only and computes no statistics.
- TV-API-06 **[16 Nov]** One host for the app: the app talks only to the Worker. Videos, trajectories and images stay in R2 with no public access, no custom domain and no presigned R2 links; the Worker reads them through its R2 binding and streams them, with HTTP range requests so the player can seek. Links the Worker hands out are on its own host, signed and short-lived. Upload links for the PC work the same way.
- TV-API-05 **[15 Nov]** Indoor flags: `POST /sessions/{id}/conditions` with exactly `{"indoor": true|false}` (anything else is refused), `GET /conditions/pending` and `POST /conditions/{id}/applied` for the PC.
- TV-APP-01 A Sessions tile and list in the existing Metro style. Each row shows date, court, duration, shots and one headline stat.
- TV-APP-02 Session detail pivots: Summary · Court · Shots · Rallies · 3D · Health.
- TV-APP-03 Court view: bounce spots coloured by speed or spin effect, filterable by shot type and hitter. Tapping a spot opens that shot's card and the video at that moment.
- TV-APP-04 Shot card: the metrics, plus a side view of the real path against the no-spin path, labelled with the spin effect in ft.
- TV-APP-05 3D view: an orbitable replay of a rally on a to-scale court, with ball trails and a time scrubber. CC chooses the rendering approach (a native 3D library, or a WebView with three.js) and justifies it.
- TV-APP-06 Trends: any metric over time, filterable by shot type, with racquet, string and tension shown as markers. Include the consistency ellipse area and the session C_D.
- TV-APP-07 Launcher live tile, in priority order:
  1. the detected-session prompt;
  2. "1 question";
  3. new-session stats, until the session is opened;
  4. the usual cues or icon.
- TV-HC-01 When a session arrives, read from Health Connect for [start − 10 min, end + 10 min]: heart rate samples, exercise sessions, active calories and steps.
- TV-HC-02 Align by UTC. Compute:
  - average and maximum heart rate;
  - time in heart-rate zones;
  - heart rate during rallies vs between rallies;
  - recovery time between points.
- TV-HC-03 Fitbit heart-rate data may be sparse. Show gaps; do not interpolate across gaps longer than 60 s.
- TV-HC-04 **[16 Nov]** All heart-rate figures are computed on the phone, from Health Connect, and stored with the session on the phone: the TV-HC-02 figures, the Health pivot (TV-APP-02) and heart-rate trends. Nothing from Health Connect leaves the phone.
- TV-HC-05 Link the session to the matching auto-detected tennis session and to the racquet in use. If several racquets are possible, ask once in the app.

## 7. Operations, testing, phases, acceptance

- TV-OPS-01 Status light and ntfy messages for:
  - import started;
  - cards safe to remove;
  - processing started;
  - session ready, with the headline stat;
  - any error, with the stage name and log path.
  - Use a long random topic name or an access token.
- TV-OPS-02 Resume after a crash or power loss from the last completed stage.
- TV-OPS-03 Retention (configurable):
  - Keep full raw footage 30 days, full-resolution rally segments 3 months, and reels, data and plots forever. At two 2-hour sessions a week this totals about 6.5 TB.
  - When the archive passes 85%, delete the oldest full-resolution rally segments of already-processed sessions before refusing any import.
  - Never delete unprocessed raw footage.
  - The weekly message reports projected disk use.
- TV-OPS-07 **[16 Nov]** Detector data is kept forever, exempt from TV-OPS-03:
  - Every frame in the hand-labelled test set (Ball check answers) and every auto-labelled training frame is saved as a full frame together with the frames just before and after it: sets of three consecutive full-resolution frames, the learned detector's input (TV-DET-04). Not just the 256 px crops.
  - They are extracted when a frame is labelled (test set) or harvested (auto-labels), before the raw footage can be deleted, as JPEG quality 95 at the camera's resolution.
  - Auto-labels are kept as whole runs of consecutive frames, so neighbouring labels share frames, and at most 20,000 new labelled frames a month are kept (spread over sessions, courts and light), matching the retraining threshold.
  - Disk estimate (to be measured on trial footage): about 2.5 MB per 4K frame. Test set: 300 frames × 3 ≈ 2.3 GB, growing slowly (about 4 GB with later batches). Auto-labels: about 21,300 frames per 20,000 labels ≈ 53 GB a month, about 0.65 TB a year. Beside the 6.5 TB footage steady state on the 12 TB archive, that fits for about 6 years; the weekly message reports it, and a second drive extends it.
- TV-OPS-04 **[16 Nov, changed]** A 2-hour session is fully processed in ≤ 12 h on the specified PC; 6 h is a goal, not a requirement. Process overnight, one session at a time, and queue the rest. At the end of TV-PH-2, the measured processing time per capture mode is part of the capture-mode decision.
- TV-OPS-05 `tools/reprocess.m` reruns any stage for any range of sessions with the current code.
- TV-OPS-06 A weekly "all OK" message with disk use, sessions processed and any warnings.
- TV-TST-01 Synthetic generator (the core test): simulate shots with known speed, spin, C_D, wind and timing.
  - Render them into both calibrated cameras on real background frames, with a blurred disc, rolling shutter, a sync offset and drift, and noise.
  - The pipeline must recover each parameter within the targets.
  - **[16 Nov]** The truth must not be made the way the fitter models it. Synthetic flights use their own model (`tv.physics.truthFlight`): ode45 rather than RK4, spin that decays, C_L that follows the spin parameter (so it changes as the ball slows) with per-shot scatter, per-shot C_D with Cross & Lindsey's spread, and wind gusts.
  - **[16 Nov]** Besides the rendered test, a fit study (`tools/fitStudy.m`) runs the reconstruction on a synthetic 90-minute singles session of about 400 shots, at the detection level (no video), and reports medians and 90th percentiles against the targets.
- TV-TST-02 Unit tests (`matlab.unittest`) for:
  - the air-density formula;
  - the RK4 integrator against ode45;
  - the court model;
  - the GPMF parser;
  - the sync estimator;
  - the in/out logic.
- TV-TST-03 A regression set of 5 real sessions; any code change re-runs them and reports metric differences.

### Field validation protocol
1. Drop test: drop a ball from a measured 2.00 m. The fitted g must be within ±1% of 9.81 m/s².
2. Radar: 50 serves and 50 groundstrokes with a radar gun beside the hitter. Compare like with like.
3. Bounce targets: 20 × 20 cm cards taped at surveyed spots.
4. Static balls at 10 surveyed positions, including on the net tape.
5. SwingVision side by side (optional).

### Phases
1. **TV-PH-0** Setup and trials:
   - PC setup script, camera settings and lens calibration;
   - the placement check (TV-CAL-03 and 04) before mounting;
   - full-length trial sessions on external power in each of 4K120 16:9, 4K120 4:3 Open Gate, 4K240 and 8K60, plus one indoor session if Chris plays indoors.
   - TV-PH-0 settles heat only. Keep the trial footage, exempt from TV-OPS-03.
2. **TV-PH-1** Automatic import and highlight reels: watcher, verify and wipe, light and alerts, metadata, pairing, rally cutting, reel.
3. **TV-PH-2** 3D tracking:
   - court calibration, sync, classical detector, 2D tracking, player tracking and identity;
   - 3D fit with drag only, speed and bounce maps.
   - At the end, run the detector and sync on the TV-PH-0 trial footage and choose the capture mode by detection rate, readout time and **[16 Nov]** the measured processing time per mode (TV-OPS-04).
4. **TV-PH-3** Physics: Magnus and wind, air density, spin metrics, synthetic tests, field validation.
5. **TV-PH-4** Cloud and app: Worker, R2/D1, Sessions UI, 2D/3D views, trends, Health Connect, equipment linking, live tile.
6. **TV-PH-5** Upgrades: learned detector, shot-type classification; automatic scoring optional.

### Acceptance criteria
| ID | Criterion | Target |
|---|---|---|
| AC-01 | Imports with no lost or corrupted file | 20 consecutive imports |
| AC-02 | Card wiped only after SHA-256 match | 100% |
| AC-03 | Rallies captured / dead time kept | ≥ 98% / ≤ 10% |
| AC-04 | Court-line reprojection error | ≤ 1.0 px RMS |
| AC-05 | Residual sync error | ≤ 0.5 ms |
| AC-06 | In-play shots with a valid 3D fit | ≥ 95% |
| AC-07 | Speed vs radar | within 2 mph for 90% of shots |
| AC-08 | Bounce position vs surveyed targets | median error ≤ 5 cm |
| AC-09 | Drop-test gravity | 9.81 m/s² ± 1% |
| AC-10 | Synthetic spin effect recovered | within 10 cm |
| AC-11 | Synthetic rpm recovered (true C_L(S) known) | within 10% |
| AC-12 | 2-hour session, cards in to app | ≤ 13 h **[16 Nov]** (was 7 h) |
| AC-13 | Shots credited to the right player, including after changeovers | ≥ 99% |

### Open questions for TV-PH-0
- Capture mode: 4K120, 4K240 or 8K60. Decided at the end of TV-PH-2 from the trial footage.
- Which courts, and whether their fences allow the 2.5–3.5 m same-side mounting. **[15 Nov]** Replaced by the lookup table.
- Opponents' stats. **[15 Nov]** Only Chris's are shown.
- Video in R2 or streamed from the PC. **[15 Nov]** R2.
- **[16 Nov]** MATLAB tests once the repository is private: options in STATUS.md, Chris to choose before making it private.

## B. Background from the original (short form)

**Feasibility.** Two things decide whether the system works: frame-accurate time sync between the cameras, and a detector that reliably finds a ball 4–7 px wide.

**Expected precision** for a tuned system, as engineering estimates:
- speed: ±1–2 mph;
- bounce location, net clearance and apex: ±3–5 cm;
- launch angle: ±1°;
- spin rate: ±25–30%;
- spin effect and spin axis: good.

The cameras see the ball's path, not its seams: spin is measured from the sideways Magnus push.

**SwingVision comparison.** SwingVision on one iPhone is mature, iOS-only and $179.99/yr. Two calibrated cameras measure distance directly, so they should beat it on 3D quantities and spin once the detector is trained, and roughly match it on line calls. Expect to do worse in the first month.

**Camera settings (both identical):**
- Resolution and frame rate: 4K120 16:9 to start; TV-PH-0 also records 4:3 Open Gate, 4K240 and 8K60.
- Lens: Wide, fixed, never SuperView.
- Stabilisation: HyperSmooth off, horizon lock off.
- Exposure: shutter about 1/1920 s; ISO auto, capped at 1600.
- Colour: white balance 5500 K; Natural profile, not Log.
- Bitrate: High.
- GPS on; timecode synced before each session in Quik; audio on.
- Auto power-off off; screens dim after 1 min.

**One-time lens calibration.** 60 s of a rigid checkerboard per camera and mode, filling every part of the frame.

**Optional ritual.** Drop a ball from head height at the centre service T after pressing record.

**Magenta cap.** Wear it for the first few minutes, such as the warm-up. Never yellow: that is the ball's hue.

**Hardware.** The recommended kit is about $4,100–4,700:
- 2 × GoPro MISSION 1 PRO;
- 3 × 512 GB microSD from GoPro's list;
- 2 power banks and 2 cables;
- 2 fence clamps;
- a checkerboard and a magenta cap;
- a closet desktop with an RTX 5060 Ti 16 GB, 8 cores, 32 GB RAM and a 2 TB NVMe;
- a 12 TB archive drive, 2 single-slot readers, an HDMI dummy plug, a USB status light and an optional UPS;
- MATLAB Home Suite plus Computer Vision Toolbox ($214/yr), and Cloudflare Workers Paid ($5/month) plus R2;
- optional validation gear: a radar gun and a 30 m tape.

A pair of HERO13 Blacks saves about $600. Home licences are for personal, non-commercial use: don't run this on a work licence.

**Closet PC.**
- Windows 11 Pro, local account `tennis`, BIOS restore on power loss, auto-login.
- At-log-on task `matlab -batch "tv.watch"`.
- Never sleep; USB selective suspend off; Windows Update restarts in a daytime window; AutoPlay off.
- C: for working files, D: for the archive.
- Tailscale plus Remote Desktop, with the HDMI dummy plug.
- ntfy on the phone, on a long random topic.
- Ventilate the closet: about 180 W while processing.

**Suggested extra features** (for later):
- string tension vs ball flight;
- swing-cue A/B tests;
- spin vs flat side view;
- serve analysis;
- consistency ellipses;
- fatigue curve;
- ball-wear indicator;
- line calls with uncertainty;
- tracer replay;
- live tile stats;
- automatic scoring.

**Sources cited in the original:**
- Videomaker, OWC and B&H (MISSION 1 PRO).
- GoPro Labs (GPS sync).
- MathWorks store and J. A. Watte (licences).
- TWU summary of Cross & Lindsey (C_D 0.507 ± 0.024; C_L vs spin).
- Sheffield Hallam (worn balls).
- Open-Meteo.
- Cloudflare R2 pricing.
- Google (Health Connect is on-device).
- ITF SwingVision report; Tennis.com; App Store.
- PC Gamer and Mixed (PC prices).
