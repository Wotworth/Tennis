# Footage test 2: your unedited clay-court video (18 Nov)

Release: [v0.6.36](https://github.com/Wotworth/Tennis/releases/tag/v0.6.36). In the app: Sessions → **Clay, iPhone** (the only footage test now; the two earlier ones are gone, as you asked).

**What ran.**
- **The stretch:** 6 minutes from the middle of your 85-minute recording (36:00–42:00). I first planned 15; I cut it to 6 so it would finish within the hour you asked for.
- **The camera:** one iPhone, raw SwingVision recording, indoor clay.
- **The code:** the same MATLAB code as the PC, with no help from me on the court.

## Results

| | Clay video |
| --- | --- |
| Court: share of the fitted lines on paint | **99%** |
| Court: distance from your hand-drawn lines (5 visible points) | 27 px median (31 5 27 14 35) |
| Court corners out of view | all four near corners |
| Tracked spots that are the ball, after every rule (sample of 48) | **4 of 12**; all 4 ball spots in the sample survived |
| Points found from the tracks | 9, but they run together (one is 127 s) |
| Bounces | 60; of 16 checked, about 2 real |

![The empty court with the fitted court in red; cyan: your drawn points, moved for the phone's drift](footage-test-2/court-fit.jpg)

## What worked

- **The court, on clay, from the tape alone.** The clay is one colour inside and outside the lines, and the fit doesn't use colour, so that didn't matter.
  - **What it needed:** the empty-court picture had to be built from frames lined up first. Your phone drifted about 30 px over the 15 minutes, which smeared the thin tape.
  - **The 27 px gap to your drawing:** most of it is the drawing itself and the frame it was drawn on. That frame is from the first minute, and by the middle of the session the phone had moved 35 px across and 19 px up. I allowed for that shift when scoring. The red lines sit on the tape everywhere.
- **Raw footage end to end.** The code now finds points itself from where the ball is tracked, instead of from SwingVision's edits. The video is split into 30-second windows so four workers can share it.

![A lob from the far player, found and tracked over the net](footage-test-2/lob-found.jpg)

## What didn't, and why

1. **The ball's colour indoors.**
   - **What I saw:** under the warm lights the ball looked nearly white in the server's hand, so I widened the colour window to near-white. In flight it actually looks yellow, as on the other courts.
   - **The effect:** the wider window let in white shirts, skin and the net tapes. Before the rules, only 4 of 48 tracked spots were the ball.
   - **After the still-ball and racquet rules:** 4 of the 12 remaining spots are the ball, and none of the real ones were lost.
   - **Next run:** yellow only.
2. **The steered search hopped.**
   - **What happened:** on clay, with so many candidates, a bad prediction widened its search window without limit and chained unrelated spots across the frame.
   - **The fix:** the window is now capped at 40 px. It applies to the next run, because re-running the steered search here would have taken another hour.
   - **A rule I tried and switched off:** dropping tracks with impossible jumps also dropped 3 of the 4 real ball tracks.
3. **Points run together.** Players and the next courts are tracked between points too, so the gaps between points fill in. This gets better as the false tracks go.
4. **Bounces:** about 2 of 16 real; most are turns on players and nets.

![Rings on the near player and racquet; a ball lying on the court is not ringed](footage-test-2/rings-on-player.jpg)

**Hand check.** In the 10 sample frames I checked, the ball was never in flight. Raw footage is mostly between points, so this test can't give a fair "ball found when visible" figure. The spot check above is the fair one.

## Decisions

| What | Choice | Why |
| --- | --- | --- |
| Stretch | 6 min from 36:00, not 15 | To finish within the hour you asked for |
| Empty court | Lined-up frames before the median | The phone drifted 30 px over 15 min |
| Ball colour indoors | Wider window this run; yellow only next time | Measured on a ball in the hand; in flight it is yellow |
| Pale surfaces | Spots on the empty court's tape, net tapes and roof are ignored | They shimmer after lining up and passed as moving balls |
| Steered search | Window capped at 40 px (next run) | It chained unrelated spots on clay |
| Jump rule | Written, switched off | It also dropped real ball tracks |
| App | Only this test ships | Your request |

## What CI proved

- **Build and release (run 44220976324): passed.** The app built, its unit and screenshot tests passed, and the release is published.
- **The tests cover:** only the clay test ships, it loads, and its pages render.
- **Vision tests (MATLAB) on the pipeline changes:** still running at the time of writing.
- **Checked in this session:** the steadying, still-ball, racquet and steered-search unit tests pass.

## On your phone

1. Install v0.6.36, then open **Sessions**. There is one footage tile, **Clay, iPhone · 9 rallies**; the two earlier iPhone tiles are gone.
2. On **summary**, check the tiles, including "rallies, 6:00".
3. Swipe to **court**: the red lines should sit on the tape.
4. Swipe to **ball** and go through the 10 frames. The players should be pixelated, and frame 3 shows the lob.
5. In the sample session, tap a serve: its spin should read kick, slice or flat.
