# 22 November: your fourteen items

All numbers here are from synthetic data unless a line says otherwise. Items are in your priority order (3, 7, 11, 8, 12, then the rest). Decisions are one line each at the end; details are in DECISIONS.md.

## 3. Model error in every uncertainty, and the corrected coverage

Coverage means the share of shots whose true error falls inside the stated band. CI run 61 flew two new 60-minute Tuesday sessions, one with gusts (193 shots) and one in calm air (196 shots), with the learned detector at 4K240 Linear.

| Band at 2 sd | Gusts | Calm | Fit alone (gusts / calm) |
|---|---|---|---|
| Bounce point (line calls) | 94% | 92% | 19% / 15% |
| Spin effect | 95% | 94% | 17% / 15% |
| Sideways curve | 89% | 100% | 8% / 9% |

- The fit's own bands were 4 to 6 times too confident, as you said. With the model-error term added, they hold the truth about 95% of the time.
- The curve is the exception: it was **too narrow in gusts and too wide in calm air**. So the gusts drive the curve's error, and only the curve's. Bounce and spin-effect errors were no larger in gusts.
- The terms are reset from these runs:

  | Term | Value |
  |---|---|
  | Bounce | 2.0 cm (95 to 96% in both) |
  | Spin effect | 4.2 cm + 8% |
  | Curve, studied gusts | 20 cm + 16% |
  | Curve, calm air | 7.5 cm + 6% |

  The weather sets where the curve term sits between calm and gusts (item 10).
- Run 61 is the data these terms were set from. The next shot-study run (running now) checks them on fresh sessions.
- **Line calls and the curve tile use only the bands with the model error.** AC-11 is kept as written; the 90th percentile is reported beside it (shotstudy.md, "Speed error median / 90th").

## 7. Dress rehearsal: a synthetic Tuesday through the whole chain

`tools/dressRehearsal.m` makes the four clips as camera-like files:
- HEVC MP4 at 239.76 frames a second (4K in CI, 960 × 540 here);
- GoPro names, in CAM1 and CAM2 folders;
- timecode and start times, with an LRV beside each;
- the machine clip split into chapters.

It runs them through `checkCameraFile`, then `quickLook` on clip 1, then `quickLook` on the rest with clip 1's calibration and each clip's own timing, then `groundTruthReport`.

**What broke between the pieces, all fixed:**
1. **quickLook calibrated with the Wide lens model on Linear pictures.** Both cameras came out 1.0 to 1.3 m and 2 to 3° off. quickLook now assumes Linear (Tuesday's setting), with an option to change it. Cameras are now within 5 cm and 0.5°.
2. **An empty-court clip crashed three stages:** the session summary, the drag refit and the upload payload. All three crashed on a clip with no shots.
3. **A clip whose last stage broke left the later clips calibrating themselves.** Clip 1's calibration is now reused whenever it exists.
4. **Chapters:** only the first chapter reached ingest, and seeking through a chapter list returned nothing. Fixed earlier today (`tv.media.joinChapters`).
5. **The drop check read the gate's rejected points instead of its kept ones.** Fixed earlier today.

`checkCameraFile` flags the synthetic files' missing telemetry track as FAIL, which is correct: they have none. Real files carry it.

**Small rehearsal (960 × 540) after the fixes:** RESULT-SMALL
**Full-size rehearsal in CI (4K240):** RESULT-4K

## 11. Cloud deploy this weekend

Manual section 2.3 has the steps, done from the tablet:
1. Make the database and the picture store in the Cloudflare dashboard.
2. Let Cloudflare build the Worker straight from this repository. You run no commands.
3. Type the two passphrases into Cloudflare's own secret fields. They never go in chat.
4. Send me two things that aren't secret: the database ID and the Worker's address. I then put the address in the app and release it.

The self-test (Settings → cloud → self-test) asks the Worker to make a sample session and a court-corners request. Your phone then shows both.

The app's cloud check runs every 15 minutes and sends no notifications (TV-UP-03). In release v0.6.50.

## 8. Graphics card and frames through memory

- **Frames through memory:** frames now come straight from FFmpeg through memory, one at a time, with NVDEC when there's a card. The temporary file is kept as the fallback and gives identical frames. The test checks that the memory path was really used. At 4K HEVC the two cost about the same, but memory avoids about 1.5 GB of disk writes per second of footage.
- **Spot-finding on the card:** it runs as whole-array maths (on the card when there is one) and finds exactly the same spots as the CPU loop. CI has no graphics card, so it checks the same maths on ordinary arrays. The Legion benchmark on day one runs it on the card.

## 12. Synthetic realism, and what changes

`tv.synth.realPatch` adds, round each ball:
- its own shadow;
- a player's shadow (sometimes with the ball in it);
- the ball on the racquet strings at contact (coming in, contact, going out), in front of or seen through the strings;
- bodies (one shirt in ten ball-coloured) and heads passing in front of or behind the ball;
- noise that grows with the light, and the rolling shutter;
- every frame coded with HEVC.

**Compression:** GoPro lists 240 Mb/s for the Mission 1 Pro, with no figure per mode. A small patch can't be given the camera's bitrate directly, so I used the quality level (quantiser 23) that x265 settles on for whole synthetic 4K frames at 240 Mb/s. Quantiser 29 is the harsher case for a busier real scene.

The size study now reports each condition apart. The shot study uses separate figures for frames in flight and for frames within 60 ms of a hit.

- **Early result (4 trials per condition):** the learned detector loses the ball on the strings. The racquet's motion swamps it: the nearest moving spot was 7 to 14 px off. A ball partly behind a body or head is also mostly lost. The colour detector keeps the ball on the strings.
- **Full study (CI, both quantisers):** RESULT-REAL

## The rest

- **2. 4K120 runtime:** manual 17.4 now times 4K120 as well. Run 1: CAM 1 at 4K240, CAM 2 at 4K120, claps as before. Optional run 2 swaps the modes.
- **4. Still balls:** the two clay balls behind the net mesh are now listed apart (`vision/testset/labels_still.csv`). They count as neither misses nor false spots and are reported on their own. Round 5 rescored: 31 of 33 balls in play at score 0.5 (was 31 of 35); tracker 30 of 33; the clay video 7 of 7.
- **5. Randomized neighbours study:** six sessions (12 rallies). Random per session: the courts' gap, the neighbours' timing and shots, the crossing ball, the stray, the walker's distance, and your own targets and speeds. RESULT-NEIGHBOURS
- **6. Spin truth:**
  - Manual 16.3 step 9 (clip 8): six balls with a band and a dot. The dot tells a whole turn from half a turn; a band alone looks the same after half a turn, which would scramble readings above about 3600 rpm. The Hero 7 films them side-on at 1080p240 from about 3 m.
  - `tools/spinFromStripe.m` gets rpm from the band's turn: within 0.5% from 1200 to 4800 rpm on a made-up 13 px ball, over four noise draws.
  - The first version passed here but failed in CI's MATLAB at 4800 rpm: it read half the rate when that ball's dot sat facing the camera, where it shows almost nothing. It now uses the machine's setting (topspin) to settle the half turn. Without the setting, such a ball is marked "unsure" instead of being given a wrong number.
  - Each frame's angle is now measured against the pass's middle frame, not just the frame before. That makes the reading about ten times steadier, and its stated uncertainty now matches its real error (the first version understated it about tenfold).
  - groundTruthReport compares it with the system's rpm for the same feeds, ball by ball, and says whether each truth falls inside the system's stated band.
- **9. Field notes in the app:** sessions page → "tuesday's measurements".
  - The form follows Tuesday's order and saves as you type. Values you must measure start empty, so a default can't pass for a measurement.
  - It writes the exact file the analysis reads (`vision/groundtruth/2026-11-24.json`; a unit test checks it against the template).
  - "Share the file" sends it to the Tuesday Drive folder. The app has no GitHub key, so it can't commit the file itself.
- **10. Wind:** the forecast gust minus the mean wind (Open-Meteo's wind_gusts_10m) scales the curve's band between calm and the studied gusts. Example shot: 9 cm calm, 23 cm in the studied gusts, 64 cm when very gusty. Each session is marked calm, breezy or gusty. The app's air row says "gusty: sideways curves less certain", and fewer curves pass the show rule. The spin effect is not marked, because its error did not grow with gusts (above).
- **13. Labelling batch:** `tools/labelBatch.m` follows the labelling design.
  - It picks from uncertain scores, lost tracks, rejected points and one-camera conflicts, ranked, at most 5 per rally.
  - Each candidate gets the full frame, the crop and 5 frames either side.
  - About 130 candidates is 15 minutes at 7 s each. Tested.
  - How it reaches your phone is a question below.
- **14. Accuracy page:** sessions page → "accuracy".
  - One section per test: drop (gravity, height), still balls, targets, machine spread, camera positions against the tape, and spin when present.
  - It shows a synthetic sample until Tuesday's results.
- **21 Nov item 6** (first Mission 1 Pro files): still waiting for the files.

## Decisions (details in DECISIONS.md)

| Item | Decision |
|---|---|
| 3 | Model-error terms reset from run 61: bounce 2.0 cm; spin effect 4.2 cm + 8%; curve 20 cm + 16% in gusts, 7.5 cm + 6% calm |
| 10 | Gusts scale the curve band only (measured: bounce and spin effect don't grow with gusts) |
| 7 | quickLook assumes Linear; empty-clip crashes fixed |
| 11 | Deploy from the tablet with Cloudflare's own build; secrets only in Cloudflare |
| 8 | Frames through memory with the file as fallback; spot-finding as array maths |
| 12 | HEVC at quantiser 23 (calibrated to 240 Mb/s) and 29 (harsher) |
| 2 | Run 1 splits the modes across the cameras; run 2 optional |
| 4 | Still balls listed apart; original labels unchanged |
| 5 | Six varied sessions per CI run |
| 6 | Band plus dot on the balls |
| 9 | The file goes by share sheet to Drive |
| 13 | Batch of about 130 per 15 minutes |
| 14 | Numbers bundled in the app until the cloud carries them |
