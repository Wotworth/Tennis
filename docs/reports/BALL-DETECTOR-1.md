# Ball detector, rebuilt overnight (18 Nov)

Release: [v0.6.37](https://github.com/Wotworth/Tennis/releases/tag/v0.6.37). In the app: Sessions → **Clay, iPhone**, re-run with the new detector.

You asked for a detector that works on any footage without me tuning it, using far less compute, and not fooled by other balls, clothes or racquets. Here is what I built overnight, how it scores on the fixed test set, and the decisions I made without you.

## How SwingVision likely does it

SwingVision says its models run on the phone's own chip, trained on a large amount of labelled tennis video. A model that has seen thousands of courts, lights and shirts learns what a ball in flight looks like across a few frames, so nobody sets colour numbers per court. Recognising the ball is learned once; on court the phone only applies it. Physics does the rest: a ball in flight follows a smooth curve, and only one ball is in play.

What I copied, with what we have:

1. **Find small things that move, with no colour.** Each frame is compared with the frames 1/30 s before and after, after lining them up for camera drift. A spot counts as moving only if a shift of 2 px can't explain it; that removes the net, tape and fence edges that sway a pixel or two. The threshold comes from each frame's own noise. Spots must fit the ball's size there, which the camera fit gives.
2. **A small learned classifier decides which spots are a ball.** It sees a 48 px patch of the three frames around each spot. It has about 63,000 numbers, tiny by today's standards, so it runs on a laptop CPU.
3. **The ball's path.** The best smooth chain of ball-like spots through time, allowing gaps where the ball is hidden. Only one ball is in play at any moment.
4. **Training data without a labelling team.**
   - Drawn balls, put into your own frames on 3D flights through the fitted camera, so they have the right size, blur and movement.
   - Self-training: confident, smooth chains in your footage become real-ball examples. Anything near a chain, or moving like a ball, is kept out of the "not a ball" examples.

The difference from SwingVision: they have years of labelled video; we have three videos. That gap closes as the PC adds sessions.

## Results on the fixed test set

The test set is 48 frames I labelled by hand: 16 from each of your three videos.
- **Found:** a ball in play with a spot within 10 px.
- **False:** a spot on anything else.

The new detector here was trained on the clay video only. Videos 1 and 2 are footage it has never seen: the honest test of "any footage without tuning".

| | Old detector (colours and rules) | New detector |
| --- | --- | --- |
| Video 1 (outdoor, evening) | 4 of 13 found, 40 false | **11 of 13 found, 0 false** |
| Video 2 (outdoor, green surround) | 9 of 13 found, 1 false | **12 of 13 found, 1 false** |
| Clay (indoor) | 2 of 7 found, 22 false | **5 of 7 found, 0 false** |
| All 48 frames | 15 of 33 found, 63 false | **28 of 33 found, 1 false** |

**A correction to the test set itself.**
- **What I found:** the new detector's "false" spots were mostly balls I had missed when labelling. A ball 3–10 px across is easy to miss in a full 1920 × 1080 frame.
- **The second look:** I checked every disputed spot from both detectors (71 in all) on five frames around it, without knowing which detector put it there. 13 were moving balls; one was too unclear to call and is ignored; the other 57 were not balls.
- **What changed:** the first labels are kept as they were, and the 13 balls are added on top.
- **Why it's fair:** both detectors are scored on the same corrected set.
- **Against your first labels:** the old detector found 10 of 20 with 68 false; the new one found 16 of 20 with 14 false, and nearly all of those 14 were the missed balls.

**An example (clay):** one of the balls I missed was moving so fast it was a faint yellow streak over the clay. The new detector tracked it across the court, and left alone the two balls lying still nearby. (No picture here: tell me if clay frames with no people in them are fine in reports, and I'll add a few.)

**What fixed it.** The first models scored real balls near zero on videos 1 and 2.
- **The cause:** their "not a ball" examples were every moving spot in a frame. Videos 1 and 2 are rally-only edits, so almost every such frame had the real ball in it, labelled "not a ball". The models learned exactly that.
- **The clay video was different:** it is raw footage and mostly between points, so it taught the model right. Trained on it alone, the model found the balls on the other two videos.
- **The guard now:** "not a ball" examples leave out anything near a ball path or moving smoothly like a ball.

**Self-training, tried and not adopted (yet).**
- **What it did:** the shipped model found 4,721 real balls in unlabelled stretches of all three videos (I checked a random 60 by eye; nearly all were real balls), and a second model was trained with them.
- **Ball by ball, it's better:** 29 of 33 found with 3 false spots, against 26 and 7.
- **With tracking, it isn't:** video 1 drops from 11 to 10 found, and the clay video goes from 0 to 2 false spots.
- **The rule:** a change counts only if no video gets worse, so the shipped model stays.
- **Next:** the tracker's thresholds were set for the first model; a model that is surer of real balls needs them re-set, on footage outside the test set.

## Round 2 (18 Nov, afternoon)

You asked me to keep training. What I did:
1. **More real footage.** The shipped model ran over 40 new stretches: 24 from the parts of the 85-minute clay recording it had never seen (the warm-up and after 51:00), and 8 more from each of videos 1 and 2. Confident, smooth paths gave 6,395 more real balls, and the misses around them gave 97,966 more "not a ball" examples, including the dome's curtain and the nets. I checked a random 60 of the new balls by eye; all but 3 to 5 were real.
2. **A separate check set.** 40 new frames (24 clay, 8 each from videos 1 and 2), kept apart from both training and the test set, labelled blind the same way. It's for comparing models and setting the tracker; the test set still gives the verdict.
3. **One model on all of it,** about 182,000 examples.

**Results**, one ball in play:

| | Shipped (v1) | Round 2 (v2) |
| --- | --- | --- |
| Test set: video 1 | 11 of 13, 0 false | 11 of 13, 0 false |
| Test set: video 2 | 12 of 13, 1 false | **13 of 13, 0 false** |
| Test set: clay | 5 of 8, 0 false | **6 of 8, 0 false** |
| Test set: all | 28 of 34, 1 false | **30 of 34, 0 false** |
| Check set | 26 of 36, 4 false | **27 of 36, 3 false** |

Better on the test set, the check set and every video; worse on none. So round 2 replaces v1.

**Three findings:**
- **The tracker needs no tuning.** One ball in play can find at most one ball per frame, and the check set has 28 frames with a ball. The shipped model already found 26 of them. Every tracker setting I tried gave the same result within one ball.
- **The test set grew by one ball.** The second look now covers every model's disputed spots. It found one more ball my labels missed (seen through the net) and one ball in the server's hand (ignored). Every model is scored on the same corrected set.
- **"Never seen" no longer applies.** Round 2 learned from all three videos, so its videos 1 and 2 numbers aren't a new-footage test. The new-footage figure stays the clay-only model's: 11 of 13 and 12 of 13.

## The clay test in the app, re-run

Same 6 minutes (36:00–42:00), same court fit; only the ball detector changed. Nothing was set for this court or its light.

| | Before (colour detector, 17 Nov) | Now |
| --- | --- | --- |
| Tracked spots that are the ball (random sample of 12, checked by eye) | 4 of 12 | **9 of 12** (one is a ball bounced before a serve) |
| Ball tracks | 697 | 133 |
| Sample frames with the ball in flight: found | 0 of 0 (none in flight in that sample) | 2 of 3 |
| Points found | 9 | 10 |
| Bounces | 60 | 141 |

What's still wrong, honestly:
- **3 of the 12 spots are false:** on the dome's curtain, the net and empty court. In one sample frame the ring is on the curtain while the ball is by the far player. The curtain's folds sway, and the classifier hasn't seen enough of that. More self-training on this court is the fix.
- **Bounces went up, not down.** 36 of the 141 are just behind a baseline at the centre mark: the server bouncing the ball before serving. They are real bounces, but not in play; telling them apart (a serve follows) is next. The court map in the app shows them as "out".
- **Some points still run together.** Between points the players hit balls back to each other, and those balls are real, so the gaps fill in. Points need the serve as their start, which comes with the bounce fix above.

## Rules retired

Each of these patched one of the colour detector's mistakes on one video. None is needed with the new detector, so it skips them all:

| Rule | Why it existed | Why it's not needed |
| --- | --- | --- |
| Ball colour window (hue, saturation, brightness), set per court | Find yellow | No colour anywhere: the classifier learned the ball's look under three lights |
| Clay settings (white-ish ball, stronger motion) | Indoor warm light | Same model on every video |
| Still-ball rule | Balls lying on court | Only moving spots are proposed |
| Racquet rule (tracks that stay on a player) | Yellow strings | The classifier was taught racquets, shirts and shoes are not balls |
| Steered search | Faint balls the colour test lost | Faint balls are proposed; tracking bridges gaps of up to 0.13 s |
| Jump rule, frame-edge rule | Tracks hopping between unrelated spots | Paths must be smooth to score; the frame's edge strip is never proposed |

What is still set by hand, and why it doesn't depend on the footage:
- **Proposals:** a 2 px shift tolerance, and a threshold set from each frame's own noise.
- **Ball size:** from the camera fit.
- **Tracking:** gap and smoothness costs, in seconds, so 30 and 60 fps behave the same.

These are listed in VISION-RETUNE.md for the PC's first sessions.

## Compute

About 0.6 s a frame on one laptop CPU core (proposals 0.35 s, classifier 0.15 s). I made the proposals 4 times faster tonight with the same result: the expensive comparison is now done only on pixels that changed. SwingVision runs in real time on the phone's AI chip, at lower resolution. The PC's graphics card will run this classifier hundreds of times faster than a CPU.

## Decisions I made overnight

You asked me to take the recommended option and tell you in the morning. All are in DECISIONS.md.

| Decision | Why |
| --- | --- |
| Spot finder plus a small classifier, not a whole-frame heat map (the spec's TrackNet wording) | Same three-frame input at a fraction of the compute; the ball is 3–25 px |
| Weights saved as plain numbers that plain MATLAB reads, not an ONNX import | Runs in CI and on the PC without the Deep Learning Toolbox; matches PyTorch to 1 in a million |
| Drawn balls fly on 3D paths through the fitted camera | The first drawn balls moved too far between frames and looked nothing like real ones |
| "Not a ball" examples exclude anything near a ball path or moving smoothly | The first models learned real balls as "not a ball" |
| Self-training brought forward (from the spec's later "free labels") | Real balls in real light, with no labelling by you |
| Test set corrected after a blind second look; first labels kept | 13 moving balls had been missed; both detectors scored the same way |
| Tracking in seconds, not frames; one ball in play at a time | Any frame rate; another ball can't take over mid-rally |
| The clay test in the app re-run with the new detector | So you can see the difference on your phone |

**Added after your answers (18 Nov):** the model (`vision/models/ballnet_v1.json`) and the test-set labels (`vision/testset`) are in the repository, numbers only; the footage test's frames pinch to zoom.

## What's next

1. **Pre-serve bounces.** Tell them from bounces in play (a serve follows), and start each point at its serve. That fixes both the extra bounces and the points that run together.
2. **The curtain.** Self-train on this court's own footage, so the dome's swaying folds stop scoring as balls.
3. **Tracker thresholds** for the surer, self-trained model, set on footage outside the test set.
4. **The full 85-minute clay video,** if you want it: about 5 hours of computing here, minutes on the PC.
