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

## Toolboxes: nothing to buy

- Graphics-card arithmetic in MATLAB (`gpuArray`) and running the cameras' windows in parallel (`parfor`) both need the **Parallel Computing Toolbox. It is in the Home Suite** the spec already lists (TV-ARCH-03), so Chris has it.
- The classifier is plain MATLAB (no Deep Learning Toolbox needed to run it, though that is in the suite too).
- Decoding stays with FFmpeg (TV-ARCH-02), which can use the graphics card's own decoder.

## What has to be built first

1. **The learned detector is not in the two-camera pipeline yet.** `tv.pipeline.run` still uses the first colour-based detector; rounds 2 to 5 run in the one-camera path only (`tv.pipeline.runSingle`). Wiring it in (spots, classifier, one ball in play per camera, then the existing sync, gate and flight fit) is the next build step, and steps 2 and 3 above belong to it.
2. The benchmark then measures all of this on the Legion per capture mode, which the spec already makes part of the capture-mode choice (TV-OPS-04, TV-PH-2).

## What could make it worse or better

- **Worse:** a busy background (wind in trees gave about 1,000 moving spots a frame on the iPhone match, three times a quiet frame's work for the classifier); a larger share of time in play (drills, a ball machine).
- **Better:** 4K at 60 frames a second halves everything; the first pass already halves the classifier's work on busy footage.
