# Processing time for one real session: projection and plan (TV-OPS-04)

19 Nov 2026. Chris asked for one real session (2 cameras, 4K, 120 frames a second, 2 hours) projected from the stage timings measured so far, against the 12-hour limit, with the plan to close the gap and whether it needs a MATLAB toolbox he doesn't have.

**Everything here is a projection.** Nothing has run on the Legion. The timings are from this cloud session (4 CPU cores, no graphics card, the Python twin of the detector) on 1080p and 2.7K footage. The day-one benchmark (`vision/tools/benchmarkPC.m`, TV-HW) replaces these numbers with measured ones.

## As things stand: about 45 to 60 hours

| | |
| --- | --- |
| Frames in a session | 2 cameras x 120 a second x 7,200 s = 1,728,000 |
| Time per frame on one of this session's cores, measured | 0.67 to 0.84 s at 1080p (2.1 million pixels); 1.4 to 2.1 s at 2.7K (5.5 million) |
| Where it goes | Finding the moving spots: 0.39 s at 1080p, about two thirds of the 2.7K figure. It grows with the number of pixels. Cutting out the candidates 0.09 to 0.30 s; the two classifier passes 0.04 to 0.22 s; decoding the rest |
| Per frame at 4K (8.3 million pixels), scaled | about 2.2 to 2.5 s on one core |
| Whole session, every frame | about 1,050 to 1,200 core-hours of this session's cores |
| On the Legion (20 cores; I take it as about 24 of this session's cores, the same assumption as the 2.5 h for the 78-minute match) | **about 45 to 60 hours.** Chris's own scaling gave 60 |

So yes: as it stands it is four to five times over the limit.

## The plan: three changes, about 5 to 8 hours

| Step | What | Why it is safe | Projected total |
| --- | --- | --- | --- |
| 0 | Every frame, CPU only | | 45 to 60 h |
| 1 | **Detector only in rally windows.** The two-camera pipeline already finds rallies from the sound first and runs detection only inside them (`tv.rally.fromAudio`, `detectAll`). | Measured on Chris's own match: SwingVision's export of the 78-minute 3 Oct match is 22.9 minutes, so the ball is in play (with SwingVision's margins) for 29% of the time. | 13 to 18 h |
| 2 | **Only the part of the picture a ball can be in.** Spot-finding on the bounding box of the court-of-interest volume, not the whole frame. | The volume mask already exists (`tv.detect.volumeMask`); this only stops work on pixels it would throw away. From beside the court I expect the box to be about 70% of the frame; that share is a guess until there is a picture from there. | 9 to 13 h |
| 3 | **Spot-finding on the graphics card.** It is plain picture arithmetic (differences of three frames, small box filters, a threshold), which is what a graphics card is for. The candidates' cut-outs and the classifier can follow it there. | The same numbers, computed elsewhere; the MATLAB test compares the two paths spot for spot. | **about 5 to 8 h** |

After step 3 the detector is no longer the largest cost. What remains, roughly: decoding 4K frames and getting them into MATLAB (1.5 to 2.5 h), the spot-finding and classifier (1 to 2 h), and the flight fits and the rest of the pipeline (1 to 2 h, scaled from the synthetic sessions in CI).

Not in the plan: finding spots on a half-size picture. At the planned mounting the ball is about 4 px across at the far corners in 4K (docs/reports/TV-PH-0a.md); at half size it would be 2 px, too small to find.

## How rally windows are found today, and what a miss costs (Chris, 19 Nov evening)

Chris asked how rally windows are found without running the detector, what happens when the first pass misses a rally, and whether decoding is inside the 5 to 8 hours.

**Today the first pass is sound only** (`tv.rally.fromAudio`, camera 1's microphone). The sound is high-pass filtered and its loudness followed in 1 ms steps; a jump above 8 times the usual level is a hit; three or more hits 0.3 to 3 s apart make a rally; the window runs from 1.5 s before the first hit to 2 s after the last, and windows less than 4 s apart are joined (TV-RAL-02). The second half of the spec's first pass (TV-RAL-01: fast ball-sized spots inside the court on small frames) **is not built**.

**A missed rally is lost silently.** Detection runs only inside the windows, so a rally the sound missed gives no shots and no rally in the app, and nothing reports it.

**On the one real recording with a camera microphone that I have, sound alone misses about half the play.** The GoPro Hero 7 clip (532.5 s): 203 hits heard, 12 windows covering 124.6 s (23% of the clip). In the 100 s where I had already run the detector over every frame, it found the ball confidently in 2,420 frames, and only 1,270 of them (52%) lie inside a sound window. Play at 30 to 33 s and 60 to 68 s has no window at all. Dropping the three-hits rule (a window at every hit) covers 50% of the clip and still does not promise every rally. One clip, one microphone, so this is a warning and not a measurement of the Mission 1 Pro; but the spec's target is 98% of rallies captured (TV-RAL-03), and sound alone is nowhere near it here.

**The plan for the first pass** (not built; my recommendation is to build it before the first full session):

1. **Sound or motion, whichever fires.** Motion is the spec's check: ball-sized moving spots inside the court volume, on small frames. A window opens when either says "play", with TV-RAL-02's rule: when in doubt, keep footage.
2. **One sweep through the file, not two.** The cheap check looks at every decoded frame; the detector runs on the frames inside windows, a couple of seconds behind. The full file is then decoded once (see below), not once for the first pass and again for the detector. If the camera writes a low-resolution copy of each recording (GoPro's LRV, one of the camera checks in the manual), the cheap check can use that and the 4K file is decoded only inside windows.
3. **A safety net for what was skipped:** the full detector on one second in every ten of the skipped footage. A ball in play found there opens a window, and `session.json` counts "rallies the first pass missed", so a miss is caught and seen instead of lost. It costs about a tenth of the skipped footage.
4. **Coverage on every session:** how much of the recording was inside windows, how many windows, and the safety net's count.
5. **Scored before it is trusted:** SwingVision's export of the 3 Oct match is an answer key for which parts of a recording were points. The first pass must put 98% of those inside a window (TV-RAL-03) before it gates anything.

Until that is built and scored, short test recordings (the Hero 7 side clips, the first Mission 1 Pro files) are processed whole.

## Decoding 4K at 120 frames a second: inside the 5 to 8 hours, and now measured

Yes, it was included: 1.5 to 2.5 h of the 5 to 8 h was decoding, for the frames inside rally windows only. That figure was an estimate. Measured since, on this session's 4 cores (software decoding, no graphics card), 180 frames of 4K 120 fps HEVC:

| | Frames a second |
| --- | --- |
| 240 Mbit/s, 10-bit: decode only | 32 |
| The same, converted to colour pixels and handed over through memory | 25 |
| 120 Mbit/s, 8-bit: decode only | 47 |
| Half size, every fourth frame only | 32 (no faster: each frame is built from the ones before it, so skipping frames saves nothing) |

Scaled to the Legion's processor (taken as 6 times this session's; an assumption until the benchmark runs): about 150 frames a second. One session is 1,728,000 frames, so:

| | Decoding | Whole session |
| --- | --- | --- |
| Rally windows from sound and a low-resolution copy; 4K decoded only inside windows (29% of the time) | about 1 h | **about 5 to 8 h** (as planned) |
| No low-resolution copy: one sweep, every frame decoded once, the detector only inside windows | about 3.2 h | about 5.5 to 7.5 h |
| No first pass at all: every frame decoded and searched | about 3.2 h | about 8 to 12 h, at or over the limit |

What this does not settle: the test file was made here by re-encoding existing footage to 4K 120, not by a GoPro; the factor of 6 is an assumption; the graphics card's own decoder should be faster and is unmeasured; the spot-finding on the graphics card (1 to 2 h of the total) is not built or measured.

**One thing to fix before the first full session:** `tv.media.readFrames` hands frames to MATLAB through a temporary file on disk. A 4K frame is about 25 MB, so the windows of one session alone would write about 12.5 TB to the SSD. Frames must go through memory instead (a pipe or a RAM disk). It does not matter for the short test clips.

## Chris's real case: 1.5 hours at 4K240, every frame (20 Nov)

Chris, 20 Nov: sessions are 1.5 hours (the warm-up is not recorded), recorded at 4K240; every frame is processed (no rally windows from sound for now); the limit is 18 hours (TV-OPS-04 and AC-12 updated). Is it inside 18 h, with the graphics card's own video decoder (NVDEC, through FFmpeg) instead of the processor?

**Frames:** 2 cameras x 240 a second x 5,400 s = **2,592,000**, 1.5 times the 1,728,000 of 2 hours at 120. At 240 frames a second the three frames the detector compares are still 1/30 s apart (8 frames), so the work per frame is the same as at 120.

| Stage | As the code is today (processor only) | With the planned changes | What it rests on |
| --- | --- | --- | --- |
| Decoding | 4.8 h on the processor (150 frames a second, scaled from this session's measurement) | **1.2 to 2.4 h on NVDEC**, running at the same time as the detector, so mostly hidden | No stand-alone NVDEC figure for the RTX 5070 Ti was found. Puget Systems says the 50 series has two decoders; I take 300 to 600 4K frames a second for both together. The day-one benchmark measures it. NVDEC reads HEVC 4:2:0 and, new in this generation, 4:2:2, 8 and 10 bit. |
| Frames into MATLAB | temporary files: about 65 TB of disk writes for one session. Not workable | through memory, cropped to the court box, in the decoder's own format (12.4 MB a 4K frame instead of 25): 1.5 to 2.5 h, alongside the detector | A pipe moved 1.4 GB/s here with a slow reader; 3 to 5 GB/s is usual for a native one. |
| Finding moving spots | 47 to 63 h (court box only) | **2 to 10 h** on the graphics card | Not built. 2 h is the card's memory speed with three times overhead; 10 h is the cautious figure used before (7 to 14 ms a frame). |
| Classifier on the spots | inside the line above | under 0.5 h on the card | 13 to 22 cuts a frame pass the first pass on real footage |
| Flight fits, events, timing | 2 to 3 h | 2 to 3 h | Scales with shots and with points per flight; 240 a second doubles the points, a shorter session has fewer shots |
| Players, calibration, outputs | about 0.5 to 1 h | about 0.5 to 1 h | Players are sampled at a fixed rate, not every frame |
| **Total** | **about 55 to 70 h** | **about 5 to 14 h** with decoding and transfer overlapped; **8 to 18 h** if nothing overlaps | |

**Answer: every-frame processing of a 1.5-hour 4K240 session fits 18 hours only once two things are built: spot-finding on the graphics card, and frames passed through memory instead of temporary files.** With those, the projection is 5 to 14 hours, and at worst (no overlap, the cautious spot-finding figure) it touches 18. NVDEC helps (it takes 3 to 4 hours of decoding off the processor and runs beside the detector) but is not what decides it; the spot-finding is. With the code as it is today, a real session would take two to three days.

Nothing here trades accuracy for speed: every frame is still searched at full resolution. The day-one benchmark (TV-HW) measures each line on the Legion, at 4K240.

## Toolboxes: nothing to buy

- Graphics-card arithmetic in MATLAB (`gpuArray`) and running the cameras' windows in parallel (`parfor`) both need the **Parallel Computing Toolbox. It is in the Home Suite** the spec already lists (TV-ARCH-03), so Chris has it.
- The classifier is plain MATLAB (no Deep Learning Toolbox needed to run it, though that is in the suite too).
- Decoding stays with FFmpeg (TV-ARCH-02), which can use the graphics card's own decoder.

## What has to be built first

1. ~~The learned detector is not in the two-camera pipeline yet.~~ **Done, 19 Nov:** `tv.pipeline.run` detects with round 5 (`tv.detect.learnedCandidates`), on the court's part of the picture only (step 2 above).
2. The first pass (sound or motion, one sweep, the safety net) and frames through memory: the two sections above.
3. Spot-finding on the graphics card (step 3 above).
4. The benchmark then measures all of this on the Legion per capture mode, which the spec already makes part of the capture-mode choice (TV-OPS-04, TV-PH-2).

## What could make it worse or better

- **Worse:** a busy background (wind in trees gave about 1,000 moving spots a frame on the iPhone match, three times a quiet frame's work for the classifier); a larger share of time in play (drills, a ball machine).
- **Better:** 4K at 60 frames a second halves everything; the first pass already halves the classifier's work on busy footage.
