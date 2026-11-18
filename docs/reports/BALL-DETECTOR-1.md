# Ball detector, rebuilt overnight (18 Nov) — draft, results to come

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

TBD

## Rules retired

TBD

## Decisions I made overnight

TBD

## What's next

TBD
