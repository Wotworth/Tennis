# Ball detector, rebuilt overnight (18 Nov)

Releases: [v0.6.37](https://github.com/Wotworth/Tennis/releases/tag/v0.6.37) (first detector), [v0.6.38](https://github.com/Wotworth/Tennis/releases/tag/v0.6.38) (frames zoom), [v0.6.39](https://github.com/Wotworth/Tennis/releases/tag/v0.6.39) (round 2), [v0.6.40](https://github.com/Wotworth/Tennis/releases/tag/v0.6.40) (tap fix, frames unpixelated), [v0.6.41](https://github.com/Wotworth/Tennis/releases/tag/v0.6.41) (bounces in play, points). In the app: Sessions → **Clay, iPhone**.

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

## The clay test re-run again with round 2 (v0.6.39)

| | v1 (v0.6.37) | Round 2 (v0.6.39) |
| --- | --- | --- |
| Tracked spots that are a ball (random 12, checked by eye) | 9 | 9 (2 of them on the next court, seen through the divider net) |
| Sample frames with the ball in flight: found | 2 of 3 | 2 of 3 (the same miss by the curtain at 5:54) |
| Points found | 10 | 7 |
| Bounces (of them pre-serve, behind the baseline centre) | 141 (36) | 144 (31) |

On these 6 minutes the two look alike; a 12-spot check can't separate them. Round 2's gain shows on the larger test and check sets.

**A pixelation fix.**
- **What I found:** in round 2's sample frames, one far player wasn't pixelated. They had stood still through that 30-second clip, so they had become part of the clip's empty-court picture.
- **The fix:** people are now also looked for against the whole session's empty court, as person-shaped regions only; smaller ones count too.
- **Checked:** every exported frame, by eye. The frames shipped in v0.6.37 and v0.6.38 were also checked: everyone in them was pixelated.

## Bounces in play and points (v0.6.41)

You asked for the pre-serve bounces next. Three things were mixed into the 144 "bounces":

| What it was | How it's told apart | Count |
| --- | --- | --- |
| The ball bounced on the spot (the server before a serve), or too little track to tell | In the second before the bounce, the ball was never more than 2.2 m from where it bounced | 36 |
| A bounce on the next court | A bounce is on the ground, so its position is exact: it is beside your court | 37 |
| A turn in the air (a hit, or the ball against the back curtain) | Its sight line reaches the ground beyond the end of the court | 10 |
| **A bounce in play** | The ball came from further away | **61** (56 inside points) |

**Points** went from 7 (one of them 70 seconds long) to **14, all between 2 and 21 seconds**.
- A point ends where the server bounces the ball again and again on one spot, so the next point starts with its serve.
- The next court's ball no longer joins your points together: a ball path whose bounces are on the next court is dropped.
- A point must hold at least one bounce in play.
- 9 of the 14 begin with a bounce in a service box about 2 seconds in, as a serve does.

**What I checked by eye:** 24 bounces, without knowing how the rule had labelled them.
- Of 8 with too little track to tell: none was in play (6 server bounces, 2 next court).
- Of 8 called "on the spot": 5 were server bounces, 2 were real bounces at the far end, 1 was a dead ball by the net.
- Of 8 called "in play" (before the next-court and in-the-air checks existed): 3 were in play, 2 next court, 1 a racquet bounce, 1 in the air, 1 nothing.

**The limit, plainly:** one camera behind the baseline can't see how far a ball flying straight away from it has come. So a few far-end bounces in play are left out, and a few server bounces (the first after the ball arrives) still count as in play; you can see them as a small cluster of rings behind the far baseline. Two cameras measure distance directly and remove both problems.

## Round 3: the curtain mistakes (tried, not adopted)

You asked for the curtain mistakes after the bounces. What I found, and what happened:

**What the mistakes are.** I looked at a sample of the round-2 model's confident ball paths on clay footage it had never seen. Most are real balls. The false ones are:
- fixed in the scene: a ball machine's blinking blue light, the curtain, the net;
- carried by a player: small white logos on dark shorts and shirts.

**A flaw I fixed in the self-training.** Any confident, smooth path became a "real ball" example, including the blinking light. Now a path that stays within a few pixels for a second is never a ball example and is taught as "not a ball". Gravity makes this safe: a ball in flight moves over a metre in a second. (A shorter window caught real far-away balls near the top of their flight, so I didn't use it.)

**Round 3** added 56,705 "not a ball" and 3,272 ball examples from the round-2 model's own run over unseen clay footage.

| One ball in play | Round 2 (shipped) | Round 3 |
| --- | --- | --- |
| Test set: video 1 | 11 of 13, 0 false | 11 of 13, 0 false |
| Test set: video 2 | 13 of 13, 0 false | 13 of 13, **1 false** |
| Test set: clay | 6 of 9, 0 false | 7 of 9, 0 false |
| Check set | 27 of 36, 3 false | 28 of 36, 3 false |

Round 3 finds one more ball on each set, but adds a false spot on video 2 (a small dark thing blowing across the court). By the rule that no video may get worse, **round 2 stays**.

**Why this didn't move.** Curtain mistakes are rare enough that 48 test frames and 40 check frames hold none of them: the check set's three false spots are a blur trail and two spots near players. So the sets can't show whether a model fixed the curtain or not. Two ways forward are in my questions.

## Round 4: one model for any camera, light and colour (19 Nov)

You asked for the most robust method with the least compute, whatever the clothing, racquets, ball colour or light, and said colour may stay only if it proves robust.

**What changed**

- **Scale.** Each cut is resized so the ball is 6 px across in it, from the camera's geometry and the moving blob's width. One model then serves a phone at 1080p and a GoPro at 4K, near or far.
- **Light.** The classifier sees brightness and motion only, each divided by the cut's own contrast, so a dim or tinted picture looks the same to it. In training, light and dark are swapped at random, so a dark ball on a pale court is as good as a pale ball on a dark one.
- **Motion threshold.** Its floor is now 5% of the frame's own brightness, not a fixed number. Dim footage: 32 of 35 balls proposed (was 29).
- **First pass.** A network a tenth the size looks at the middle of each cut first and throws out what is plainly not a ball. Only about one spot in eight on busy footage reaches the classifier.

**Colour: measured, not needed.** I trained two versions on the same examples: no colour, and colour as a hint (blanked a third of the time in training so it couldn't lean on it).

| One ball in play | Round 2 (shipped) | Round 4, no colour | Round 4, colour hint |
| --- | --- | --- | --- |
| Test set as filmed | 30 of 35, 0 false | 28 of 35, 2 false | 28 of 35, 3 false |
| Check set | 27 of 36, 3 false | 27 of 36, 3 false | 27 of 36, 3 false |

The colour-hint version's 3 false spots were not checked by eye; they are counted as false.

**The same test frames in other lights.** Balls found of 35 by the classifier alone (score above 0.5, before the tracker), with its false spots in brackets. The tracker removes most false spots: as filmed, round 4's 33 become 2.

| Condition | Round 2 | Round 4, no colour | Round 4, colour hint |
| --- | --- | --- | --- |
| As filmed | 31 (21) | 30 (33) | 29 (35) |
| No colour at all | 30 (29) | 31 (31) | 31 (25) |
| Warm cast | 29 (24) | 31 (25) | 31 (21) |
| Cool cast | not run | 31 (28) | 31 (25) |
| 40% of the light | 28 (12) | 30 (39) | 30 (39) |
| Light and dark swapped | 23 (24) | 31 (32) | 31 (27) |

**What this says**

- **Colour adds nothing measurable.** The two round-4 versions tie on every set and condition. The no-colour one is kept: it is cheaper and has nothing to break when the light changes.
- **Round 4 holds its level in every light** (30 or 31 of 35). Round 2 falls to 28 in dim light and 23 with light and dark swapped.
- **As filmed, on these three videos, round 2 is still slightly ahead:** 2 more balls and 2 fewer false spots on the test set, level on the check set. Round 2 learned these videos' own colours, which helps on them and nowhere else.
- **So nothing changes in the app.** By the rule that no video may get worse, the clay test keeps round 2. Round 4 (`vision/models/ballnet_v4.json`, with its first pass) is in the repository as the any-camera model. It is what I'll train further on your new sessions and use on the first GoPro footage.

**Compute, one laptop CPU core, per frame**

| | Busy footage (video 1, about 500 moving spots) | Quiet footage (clay, about 26) |
| --- | --- | --- |
| Round 4, classifier on every spot | 1.67 s | 0.43 s |
| Round 4 with the first pass | 0.84 s | 0.40 s |

- With the first pass, a busy frame splits into: finding moving spots 0.44 s, cutting them out 0.14 s, first pass 0.05 s, classifier 0.10 s.
- The first pass changes no result on the test set (28 of 35, 2 false, the same per video).
- Finding the moving spots is now the largest cost on any footage, so that is the next thing to speed up.
- Round 2's "about 0.6 s" was measured on quieter footage than video 1; I did not time it on video 1, so I can't give a like-for-like figure.

**MATLAB.** The pipeline runs round 4 with the first pass (`tv.detect.ballScores`), with the same numbers as PyTorch to six decimal places (tests). A new test draws a moving ball in four colours and lights (yellow, white on blue, dark on pale, dim) and round 4 calls each a ball.

## Round 5: the ball's shadow (19 Nov, overnight)

**Why.** On Chris's new footage in strong low sun (docs/reports/NEW-FOOTAGE-1.md), round 4 followed the ball's shadow: 12.8% of its tracked spots on a held-out stretch of the 3 Oct iPhone match. Round 4 was trained to take a dark thing on a pale court as readily as a pale thing on a dark one, and a shadow is exactly that.

**What changed.**

- Two more input pictures for the classifier (7 channels instead of 5): how much the colour of each pixel changed against each neighbour frame once any change of brightness is taken out. A shadow (the same surface, darker) leaves almost nothing; a ball with a colour of its own leaves a remainder. It compares the same patch with and without the thing on it, so it does not depend on the light or on what colour the ball is (`tv.detect.ballNet`, `vision/ml/model.py`).
- Training data: everything from round 4, plus stretches of the three new videos (the GoPro clip, the iPhone match, the SwingVision export of the same match; a later stretch of each held out), plus SwingVision's bounce marks as weak "the ball was here" hints, plus drawn shadows on every court. Mined shadows (darker than their surround, colour unchanged; checked by eye, 24 of 24) are "not a ball" examples. 306,336 examples, 124,398 of them balls.
- Light and dark are swapped in training only for examples whose colour does change, so a dark colourless spot is never taught as a ball.
- The first pass is unchanged (round 4's).

**Results.** Round 4 against round 5, tracker with one ball in play unless stated.

| | Round 4 | Round 5 |
| --- | --- | --- |
| Fixed test set: balls found / false spots | 28 of 35 / 2 | 30 of 35 / 2 |
| per video (1, 2, clay) | 10 of 13 / 1, 13 of 13 / 1, 5 of 9 / 0 | 10 of 13 / 2, 13 of 13 / 0, 7 of 9 / 0 |
| Check set | 27 of 36 / 3 | 28 of 36 / 3 |
| Held-out iPhone match (30 s): frames tracked; shadows among them | 868 of 1,776; 12.8% | 611; 2.5% |
| Held-out SwingVision clip (4 points): same | 1,085 of 1,450; 12.1% | 968; 1.9% |
| Held-out GoPro (20 s): same | 454 of 1,184; 6.2% | 391; 0.3% |
| By eye, 12 random tracked spots per held-out stretch: the ball | 24 of 36 (1 shadow) | 28 of 36 (0 shadows) |

The classifier alone at each test frame (score above 0.5, before the tracker), found / false:

| Condition | Round 4 | Round 5 |
| --- | --- | --- |
| As filmed | 30 of 35 / 33 | 30 / 13 |
| Grey | 31 / 31 | 29 / 10 |
| Warm | 31 / 25 | 32 / 12 |
| Dark | 30 / 39 | 30 / 9 |
| Light and dark swapped | 31 / 32 | **13 / 16** |

- **Fewer tracked frames is mostly fewer mistakes.** On the held-out iPhone stretch round 5 tracks 257 fewer frames. Of 12 random spots only round 4 tracked: 4 shadows, 7 nothing visible (trees, shade), 1 real ball. Of 12 random spots only round 5 tracked (63 in all): 4 balls, 4 the far player's racquet head (one two-second stretch between points), 4 nothing clear.
- **The price: a ball darker than the court behind it.** With light and dark swapped round 5 finds 13 of 35. A very dark spot is "the court, only darker" whatever its real colour, which is what a shadow is; one camera's picture cannot tell the two apart. Outdoors a tennis ball is among the brightest things on the court, so this was accepted for the new cameras; round 4 stays in the repository as the fallback.
- Video 1 has one more false spot on the test set (a cap logo as a head turns, and a shirt, both at low confidence) and video 2 one fewer; the total is level.
- Drawn shadows (the court at 30 to 75% of its brightness, moving as a ball does): round 4 scores them 0.95 to 1.00, round 5 under 0.1 with a soft edge and under 0.4 as a crisp disc (`tests/ballNetTest.m`).
- Against SwingVision's 8 bounce marks in the held-out points both models have the ball at 5.

**Adopted** as the model for new cameras (`vision/models/ballnet_v5.json`, with round 4's first pass). Round 2 stays where it is shipped in the app's footage tests. CI run 48 (MATLAB): 140 pass including the two round-5 sections of `ballNetTest`; the 2 failures are the known adjacentTest sections.

**Is it the new input or the new footage?** The same examples without the colour-change input (5 channels, no light/dark swap): test set 27 of 35 with 1 false spot (round 5: 30, 2; round 4: 28, 2). Taught to refuse shadows without seeing colour, it refuses balls too; the new input is what lets round 5 drop shadows and keep balls. Its held-out figures are to be added.

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

Rounds 1 to 3: about 0.6 s a frame on one laptop CPU core on quiet footage (proposals 0.35 s, classifier 0.15 s). The proposals were made 4 times faster on the first night with the same result: the expensive comparison is done only on pixels that changed. Round 4's figures, with its first pass, are in its section above. SwingVision runs in real time on the phone's AI chip, at lower resolution. The PC's graphics card will run the classifier hundreds of times faster than a CPU.

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

1. **Your SwingVision exports.** Their bounce dots become weak labels (docs/reports/OVERLAY-READER-1.md): the detector's own tracks near each dot give new ball examples from new courts and lights, with the guard that stops real balls being taught as "not a ball".
2. **A bigger test set.** Hand-checked frames from the new courts, two or three courts kept out of training altogether.
3. **Finding moving spots faster,** now the largest cost.
4. **The first GoPro footage:** a short self-training round on its own backgrounds, since everything so far is filmed from behind the baseline.
