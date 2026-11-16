# Part D: camera time sync, answers (16 Nov). No changes made.

Frame rate in this note: 4K120, which records at 119.88 frames per second, so one frame is **8.34 ms**.

## 1. How the cameras are synchronised today

The cameras are not wired together, so their frames are never taken at the same instant, and the pipeline never pairs frames by number (TV-SYNC-05). Each detection gets its own time on camera 1's clock, and the 3D flight is fitted to all detections at their own times.

**Recording:**
- Both cameras record independently.
- The spec asks for GoPro's Timecode Sync in the Quik app before each session (camera settings, section B). That sets both cameras' clocks to within a few frames (see question 4).
- Audio is recorded, but sync does not use it (question 3).

**Processing, in three steps:**
1. **Coarse** (`+tv/+pipeline/run.m`, `probeBoth`). Each file's start time gives camera 2's rough offset.
   - The spec says to use the timecode track, or GPS time from the GoPro metadata.
   - **The code currently uses the file's creation time.** Reading the MISSION 1 PRO's timecode track is still to do, and needs a real file to test against.
   - Expected error: a frame or two.
2. **Medium** (`+tv/+sync/clockLine.m`, 16 Nov).
   - For each 10-minute window, camera 2's offset is chosen so the two cameras' sight lines to the ball cross. With the wrong offset the ball has moved between the two views, and the lines miss each other.
   - A straight line through the windows gives the offset Δ and the drift ε (clock-rate difference).
   - Video only.
3. **Fine** (`+tv/+recon/refineSession.m`). The final answer.
   - Δ, ε and each camera's rolling-shutter readout time τᵣ are fitted together with every flight, by minimising how far the fitted 3D flights land from the detections in both cameras (TV-SYNC-03).
   - Each detection's time includes its image row: the sensor reads the frame top to bottom over τᵣ, about 8 ms.
   - τᵣ will be measured once per camera and mode from a flickering lamp (TV-SYNC-06), because ball flights alone can't pin it down.

## 2. Accuracy

- **Target:** 0.5 ms (AC-05, TV-SYNC-04), which is **0.06 of a frame** at 4K120.
- **Achieved, synthetic:**
  - 0.22 ms on the 25-second pipeline test;
  - 1.4 ms at mid-session in the 90-minute fit study, after the 16 Nov drift fix. That is over the 0.5 ms target: see gap G1 in question 9.
- **What a timing error costs for a 100 mph (44.7 m/s) ball:** the ball moves 4.5 cm per millisecond. The 3D error is of that order, depending on the angle between the flight and the two sight lines.

| Sync error | Fraction of a frame (4K120) | Ball movement at 100 mph |
|---|---|---|
| 0.5 ms | 0.06 | 2.2 cm |
| 1 ms | 0.12 | 4.5 cm |
| 4.2 ms (half a frame) | 0.5 | 19 cm |
| 8.3 ms (one frame) | 1 | 37 cm |
| 50 ms (Timecode Sync's stated limit) | 6 | 2.2 m |

So Timecode Sync alone is far too coarse for measuring, and the video steps 2 and 3 are what make the measurements possible.

## 3. Sound and sync

- **The code:** no part of the pipeline uses audio arrival times for sync, or for anything to do with timing. Sync is video only (steps 2 and 3).
- **The spec:** TV-SYNC-02 still describes an audio method (envelope cross-correlation, with each sound corrected for its travel time to each camera). That text predates the sight-line method and was never built. **Proposal:** rewrite TV-SYNC-02 to describe the sight-line method, and drop the audio method.
- **Why sound is a poor sync source:** the same hit reaches the two cameras at different times (sound travels about 34 cm per millisecond, and the cameras are 20–30 m apart). Correcting for that needs the hit's 3D position, which itself needs sync. And each camera adds its own unknown delay between sound and picture (question 7).

## 4. GoPro MISSION 1 PRO Timecode Sync

**What I could confirm:**
- **It exists, and is called "Timecode Sync".** GoPro's MISSION 1 Series manual, as quoted in search results: "available through the GoPro Quik app. Open the camera control screen, tap Sync Timecode, and scan the QR with any MISSION 1 Series camera, using any mode or preset. The camera will let you know if the sync was successful." [GoPro MISSION 1 Series manual (PDF)](https://static.gopro.com/assets/blta2b8522e5372af40/blt58994dc5c9a8e580/6a144dcaa924ef7755edc65e/M1Series_UM_en-US_REVB.pdf). GoPro also lists "Timecode Sync for multi-camera shoots" among the camera's features (reported by [PetaPixel](https://petapixel.com/2026/04/14/gopro-mission-1-pro-8kp60-video-50mp-photos-10-bit-log-5-hour-battery/)).
- **What it does:** the phone shows a QR code holding the current time. Each camera reads it and sets its internal timecode clock. Each recording is then stamped with timecode, so editors (and this pipeline) can line the files up.
- **Accuracy:** GoPro's support article for HERO12 Black gives a sync precision of **under 50 ms**. The same article warns that sync starts to drift if the cameras are on (not necessarily recording) for more than **60–90 minutes**, and must be redone after **every power cycle**. Keep frame rates the same on all cameras. [GoPro: How To Use Timecode Sync](https://community.gopro.com/s/article/HERO12-Black-Timecode-Sync?language=en_US). Third-party QR tools report "typically within a frame or two".
- **Wired option:** a reviewer reports the MISSION 1 PRO can take linear timecode (LTC) through a 3.5 mm mic input with the Media Mod ([Newsshooter](https://www.newsshooter.com/2026/08/26/gopro-mission-1-pro-ils-review/)). That needs a timecode generator, which we don't have.

**What I could not confirm:**
- The network rules here block GoPro's sites. I added them to the environment, but downloading the manual was then refused in this session. So the manual's wording above comes from a search engine's excerpt, and **I have not read GoPro's pages myself**.
- I could not confirm:
  - that the 50 ms figure applies to MISSION 1 (the article is for HERO12);
  - whether the MISSION 1 PRO writes the timecode into the video file in a form the pipeline can read (a timecode track, or the GPMF metadata).
- **To settle it:** record two clips after Timecode Sync and check the files (a TV-PH-0 task).

**How the design uses it:** only as the coarse step, to save the medium step's search. If the timecode is missing or wrong, the medium step searches ±60 ms around the file creation times instead. The design doesn't depend on Timecode Sync being accurate, only on it being within a few frames.

## 5. A sync check on every session

**What exists:**
- The fine fit reports each flight's error in pixels, and session.json stores Δ, ε and τᵣ.
- A bad offset shows up as a large stereo error on fast shots.

**What is missing:**
- No explicit pass/fail check.
- No independent cross-check from sharp events seen by both cameras.

**Proposal (G4):**
- Every bounce gives a sharp moment in each camera: the instant the ball's path turns upward, found to a fraction of a frame by fitting the incoming and outgoing paths. Bounce times can be computed per camera, and their offsets compared with the fitted Δ and ε.
- **Pass:** median difference under 0.5 ms, and no 10-minute window off by more than 1 ms.
- **On failure:**
  - the session is flagged "timing uncertain" in the app, with the window it failed in;
  - speeds and spin from that window are greyed out;
  - line calls stay (bounce positions barely depend on timing).

## 6. Drift and dropped frames over a long session

- **Drift:**
  - The clock-rate difference ε is fitted (medium step per 10-minute window, then the fine fit). The fit study recovered 39.9 ppm against a true 40 ppm over 90 minutes.
  - Only a straight-line drift is modelled. A clock whose rate changes as the camera warms up would leave a curved error (gap G2).
- **Dropped or duplicated frames:**
  - Every frame's time comes from its own presentation timestamp in the file, never frame number ÷ frame rate (TV-ING-10). A dropped frame leaves a gap in time, and the rest stay correct.
  - Not verified on MISSION 1 files: whether the camera ever drops frames, or repeats one with a new timestamp. A TV-PH-0 trial should check the timestamps of a full 2-hour recording.

## 7. A start-of-session clap

**Is it valid?** Yes in principle, as a check, but it can't beat the video fit, for two reasons:
- **Travel time** is the easy part. Each camera's distance to the clap comes from the calibration, to a few cm. At 343 m/s, 3 cm is under 0.1 ms. You would clap at a marked spot, such as the centre service line T, so its position is known.
- **Each camera's own delay between sound and picture** is the hard part. The camera records sound and picture through separate paths and lines them up in the file. That alignment is accurate to a few milliseconds at best for video editing, and is not guaranteed constant between power cycles, settings or firmware. Any difference between the two cameras' delays goes straight into the measured offset. The clap is useful only if both delays are constant and known.

**Measuring the delays:**
1. Film a sharp event, close to one camera, that can be both seen and heard. A clap 1 m from the lens works: its travel time is 3 ms.
2. Compare the audio onset with the visual moment the hands meet.
3. Repeat across power cycles and days.
4. If the spread is under about 0.3 ms, the delay is usable; otherwise the clap can only check to a few milliseconds.

I can't predict the spread. It has to be measured.

**Accuracy, if the delays are constant:** about 0.2–0.5 ms, limited by:
- the sharpness of the clap's onset;
- the sample rate (audio sample spacing is 0.02 ms at 48 kHz);
- the delay calibration.

**The visual cross-check:** yes. The moment the hands meet can be found in each camera to about 1–2 ms, by fitting the hands' approach over a few frames and using each image row's own time. That is a pure video sync event, independent of audio, but coarser than ball flights, which give many sharp, fast events per session.

**Locating the cameras:** agreed. A clap mixes the clock offset with the travel time, so it can't locate the cameras. The court lines do that.

## 8. A start-of-session ball drop

- **Gravity check:** yes.
  - Fit the fall with gravity left free: the flight model, with drag (needed: drag is about 5% of gravity at 5 m/s), fitted to both cameras.
  - The fitted gravity tests scale and timing together. A 1% scale error, or a 0.5% clock-rate error, both show up as about 1% error in gravity.
  - **Pass:** 9.81 m/s² ± 1% (the spec's AC-09). A 1.5–2 m drop gives about 0.6 s of fall, about 70 frames per camera, enough for ±1%.
- **The bounce as a sync event:** yes. Both cameras see the bounce, and fitting the falling and rising paths gives its time in each camera to a fraction of a frame (about 0.5 ms). That is a clean check of the offset at the start of the session.
- **Drop height:** it doesn't need to be known. The 3D fit measures the height, and the court lines give the scale.
  - Drop from a comfortable height, about 2 m (arm raised above the head), so the fall is long.
  - Drop at a marked spot in both cameras' view, such as the centre service line T.
  - No post is needed, so an obstructed post (Part C) doesn't matter.
  - Stand clear of the ball's path for both cameras, and let it bounce 2–3 times.

## 9. Gaps, risks and recommendations

| Gap | Risk | Recommendation |
|---|---|---|
| G1 | 90-minute fit study: 1.4 ms mid-session error, over the 0.5 ms target | Fit Δ and ε per 15-minute window in the fine step, joined smoothly, instead of one line for the session. Recheck in the fit study. |
| G2 | Drift that changes with temperature isn't modelled | Covered by G1's piecewise fit. |
| G3 | Coarse step uses file creation time; MISSION 1 timecode not yet read | Read the timecode track or GPMF time once real files exist (TV-PH-0). Keep the ±60 ms search as a fallback. |
| G4 | No explicit per-session sync check | Add the bounce-based check of question 5, with an app flag. |
| G5 | Readout time τᵣ needs the flicker measurement (TV-SYNC-06) | Keep it in TV-PH-0. |
| G6 | Spec TV-SYNC-02 describes an audio method that isn't built | Rewrite it to the sight-line method (question 3). |
| G7 | Timecode Sync drifts after 60–90 minutes on, and is lost at power-off | Redo Timecode Sync just before pressing record, and keep the cameras powered from the banks. The video steps absorb what is left. |

**Ball drop: adopt.** It costs 10 seconds, needs no extra kit, and gives a gravity check and a sync check at the start of every session. It is spec's existing "optional ritual", made standard and measured.

**Clap: don't adopt now.** It only adds to the ball drop once each camera's sound-to-picture delay has been measured and shown to be constant. That can be tested in TV-PH-0 at no cost, and adopted later if the numbers are good.
