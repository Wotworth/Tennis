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
- Run 61 is the data these terms were set from. Rerun on the same two sessions with the new terms: bounce 96% / 95%, spin effect 96% / 95%, curve 97% / 95% (gusts / calm). That only shows the terms were set right.
- **Check on fresh shots** (CI, session seed 11, which the terms were not set from):

  | Band at 2 sd | Gusts (211 shots) | Calm (228 shots) |
  |---|---|---|
  | Bounce point | 96% | 100% |
  | Spin effect | 98% | 99% |
  | Sideways curve | 94% | 95% |

  The terms hold on fresh shots. In calm air the bounce and spin-effect bands are a little wide: 1 sd already holds 93 to 95%, where about 68% is ideal. That's the safe direction for line calls, so I've left them as they are.
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

6. **A clip whose flight was split in two broke the 3D step** (Octave only: it stacks an empty row on a column where MATLAB doesn't mind). Fixed so both accept it.
7. **A dropped ball's bounce, found before the "hit", left no path between them** and broke the shot measurements. That shot now gets no flight time instead of breaking the clip.

**Small rehearsal (960 × 540, here):** clips 1 and 2 now run through the whole chain; before these fixes, clips 1 to 3 broke. The full four-clip run here takes over two hours in Octave, so the complete check is the 4K one in CI.

**Full-size rehearsal in CI (4K240):** before the fixes, clips 1 to 3 went through the whole chain in MATLAB, each finding its rally (2, 8 and 3 shots). Clip 4 then ran out of GitHub's 6-hour limit. The first pass over each clip takes 26 to 79 minutes on CI's small machines with no graphics card, so it says nothing about the Legion's time. The rehearsal now runs as two jobs (clips 1 and 2; clips 1, 3 and 4). RESULT-4K

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

**Full study (CI, 60 trials per condition and size, the 201-shot gusty Tuesday session):**

| Learned detector | Shots found (AC-06: 95%) | Speed within 2 mph (AC-07: 90%) | Speed error median / 90th, mph | Bounce error median, cm | Spin effect error median, cm |
|---|---|---|---|---|---|
| Clean pictures (before) | 193 of 201 (96%) | 97% | 0.47 / 1.25 | 1.7 | 7.4 |
| Realistic, quantiser 23 | 172 of 201 (86%) | 84% | 0.69 / 2.41 | 1.3 | 9.8 |
| Realistic, quantiser 29 | 150 of 201 (75%) | 80% | 1.12 / 2.78 | 1.4 | 13.1 |

- **This changes the answer.** On realistic pictures the learned detector misses AC-06 and AC-07. The loss is round the hits: the 60 ms either side of contact is where the shot's start and speed come from.
- Near a hit (strings 40%, a body in front 30%, behind 30%), the learned detector finds the ball in 31 to 47% of frames at 3 to 8 px, at quantiser 23. On the strings alone it finds it in under 10%: the racquet's own motion swamps it. The colour detector finds it in 74 to 90% of frames at 4 to 8 px.
- At quantiser 29 the learned detector also weakens in flight: 64% found at 4 px, against 90% at quantiser 23.
- Bounces stay good (1.3 to 1.4 cm median): they are far from the players.
- The spin-effect band holds the truth less often on realistic pictures (91% at quantiser 23, 83% at 29, against 95 to 96% on clean ones). Bounce and curve bands still hold (96 to 99%).
- **What I'm testing (CI now):** near a hit, use the colour detector's spot wherever the learned one has none ("learnedColour"). Result (CI, the same session at quantiser 23):

  | Near a hit | Shots found | Speed within 2 mph | Speed error median / 90th, mph | Spin-effect band holds (2 sd) |
  |---|---|---|---|---|
  | Learned detector alone | 172 of 201 (86%) | 84% | 0.69 / 2.41 | 91% |
  | Learned, else colour | 180 of 201 (90%) | 93% | 0.60 / 1.78 | 96% |

  - Near a hit the combination finds the ball in 80 to 96% of frames at 4 to 8 px (the learned one alone: 38 to 47%).
  - AC-07 is met again; AC-06 is still short (90% against 95%).
  - The study picks the colour spot nearest the true ball, so it is a best case: on real pictures the colour detector also fires on yellow-green shirts and the like.
  - This is not in the pipeline yet; see the question below.

## The rest

- **2. 4K120 runtime:** manual 17.4 now times 4K120 as well. Run 1: CAM 1 at 4K240, CAM 2 at 4K120, claps as before. Optional run 2 swaps the modes.
- **4. Still balls:** the two clay balls behind the net mesh are now listed apart (`vision/testset/labels_still.csv`). They count as neither misses nor false spots and are reported on their own. Round 5 rescored: 31 of 33 balls in play at score 0.5 (was 31 of 35); tracker 30 of 33; the clay video 7 of 7.
- **5. Randomized neighbours study:** six sessions (12 rallies). Random per session: the courts' gap, the neighbours' timing and shots, the crossing ball, the stray, the walker's distance, and your own targets and speeds.
  - **It fails on varied sessions.** Shots found: 39 of 49 (80%). Line calls right: 35 of 39. Your ball's detections rejected: 12.1% median, worst 34.4% (AC-15 limit 2%). Neighbours' detections accepted: 0.04% median, worst 0.64% (AC-14 is met). Identity swaps: 4 in all, in two sessions.
  - The 21 Nov fixes were tuned on the one neighbours session in adjacentTest and pass there. They don't carry over to other gaps, timings and crossings: the gate now keeps the neighbours out but throws away too much of your ball.
  - | Session | Gap, m | Shots found | Calls right | Your ball rejected | Swaps |
    |---|---|---|---|---|---|
    | 1 | 3.46 | 7 of 9 | 7 of 7 | 10.4% | 0 |
    | 2 | 3.19 | 6 of 6 | 6 of 6 | 6.9% | 0 |
    | 3 | 3.90 | 6 of 8 | 5 of 6 | 12.7% | 2 |
    | 4 | 3.06 | 5 of 8 | 4 of 5 | 34.4% | 2 |
    | 5 | 3.99 | 7 of 9 | 7 of 7 | 11.5% | 0 |
    | 6 | 4.11 | 8 of 9 | 6 of 8 | 20.6% | 0 |
  - **Why** (CI rerun, which records the reason for each rejected detection of your ball):
    - *"Mostly outside"*: 816 detections in session 4 and 483 in session 6, the two worst sessions. The gate drops a whole track when over half of its 3D points lie outside your court's box. When the tracker has joined your ball to a neighbour's ball, or your ball flies on past the box after an out shot, the whole track goes, including the part over your court.
    - *Flight fit*: 94 to 210 detections in every session, dropped as outliers when the flights are fitted.
    - The rest: under 35 per session (one camera only, paired with the wrong ball, overlapping a better track).
  - **Proposed fix:** judge "mostly outside" on each stretch of a track rather than on the whole track, so only the stretch outside your court goes; then look at the flight-fit outliers. The other rules (a ball rolling along the ground, the epipolar check) still keep the neighbours out. It will be retuned on these six sessions and checked on six fresh ones, with adjacentTest kept. Each CI run of the study takes about 6 hours. Question 2 below sets when.
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
| 3 | Model-error terms reset from run 61: bounce 2.0 cm; spin effect 4.2 cm + 8%; curve 20 cm + 16% in gusts, 7.5 cm + 6% calm; checked on fresh shots (94 to 100%) |
| 10 | Gusts scale the curve band only (measured: bounce and spin effect don't grow with gusts) |
| 7 | quickLook assumes Linear; empty-clip, split-flight and early-bounce breaks fixed; 4K rehearsal in two CI jobs |
| 11 | Deploy from the tablet with Cloudflare's own build; secrets only in Cloudflare |
| 8 | Frames through memory with the file as fallback; spot-finding as array maths |
| 12 | HEVC at quantiser 23 (calibrated to 240 Mb/s) and 29 (harsher); learned-else-colour near hits measured, not yet in the pipeline |
| 2 | Run 1 splits the modes across the cameras; run 2 optional |
| 4 | Still balls listed apart; original labels unchanged |
| 5 | Six varied sessions per CI run; they fail AC-15, so the gate gets retuned on them and checked on six fresh ones |
| 6 | Band plus dot on the balls; the machine's topspin settles the half turn |
| 9 | The file goes by share sheet to Drive |
| 13 | Batch of about 130 per 15 minutes |
| 14 | Numbers bundled in the app until the cloud carries them |

## Questions

1. **Near-hit fallback in the pipeline** (item 12): near a hit, take the colour detector's spot where the learned one has none.
   - A. Build it as a switch and choose on Tuesday's real hits (the machine clips have known speeds). **Recommended**: the gain is measured on synthetic pictures only, and the colour detector also fires on ball-coloured clothing.
   - B. Build it and turn it on now.
   - C. Leave it until after Tuesday.
2. **Courts next to yours on Tuesday:** will they be in use? If yes, the neighbours gate gets fixed before Tuesday; if not, it can follow.
3. **Labelling batch** (item 13): how Tuesday's batch reaches your phone. A: the cloud Worker, with a write key put in this session's environment (recommended, once the cloud is up). B: a file in the Tuesday Drive folder that the app imports.
4. **After your cloud deploy:** send the database ID and the Worker's address (not secret).

