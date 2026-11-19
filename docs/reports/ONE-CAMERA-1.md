# One camera blocked: the flight fit when only one camera sees the ball

19 Nov 2026. Chris's plan of 18 Nov: make the two-camera flight fit handle stretches where only one camera sees the ball, and report how much accuracy drops on synthetic flights with one camera blocked. Everything here is SYNTHETIC: two 4K GoPros at the side fence, 120 frames a second, half a pixel of detector noise.

**How it carries over to the GoPros:** this is the two-camera system's own flight fit (`tv.recon.segments`, TV-REC-01), not a stand-in.

## What was missing

The fit needed at least 4 detections from each camera in every stretch between two events (a hit, a bounce). A stretch that one camera missed entirely was skipped, and its flight and its events were lost.

## What it does now

1. **Part of a flight blocked:** nothing special is needed. The flight is fitted to whatever each camera saw, and the detections the one camera made alone are used too.
2. **A whole flight blocked in one camera:** the flight is fitted from the other camera's sight lines and the physics, and pinned to its neighbours:
   - at a bounce, to the point on the ground where the flight before came down or the flight after left (to 3 cm);
   - at a hit, to where the neighbouring flight was at that moment (looser, by how far the ball travels in the gap between them).
3. **Two safeguards,** each added after the existing pipeline test caught a phantom hit:
   - a one-camera flight needs pins at both ends, or at least 15 detections with one pin (a 6-detection stub at the end of a rally, the ball running on into the back fence, had become a hit);
   - where it meets a neighbour, the ball's velocity must change by at least 4 m/s, as it does at any bounce or hit (the blurred first frames after a hit, seen by one camera, had become a flight of their own, with a second "hit" 90 ms after the real one).
4. Such a flight is marked one-camera in the results, so its speed and bounce can be shown with more caution.

## First check: one rally, four cases

A serve-like drive, its bounce, the rise to the next hit, and the reply (`vision/tests/oneCameraTest.m`, run in CI with MATLAB).

| Camera 2 blind for | Flights found | Bounce error | Next hit |
| --- | --- | --- | --- |
| Nothing | 3 of 3 | 0.1 cm | 13 ms early, 8 cm off |
| The middle half of the flight to the bounce | 3 of 3, camera 1's detections in the gap used | 0.1 cm | 13 ms early, 8 cm off |
| The whole flight to the bounce | 3 of 3, the first from one camera | 0.1 cm | 13 ms early, 8 cm off |
| The bounce to the next hit | 3 of 3, the middle one from one camera (was 2 of 3 before) | 1 cm | 25 ms early, 58 cm off |

- The bounce barely moves, because the flight on the other side of it is still seen by both cameras and pins it.
- The hit that ends a one-camera flight is found later or earlier by about a frame more, and at ball speed that is half a metre along its path. Its time stays inside the pipeline's 30 ms limit.

## The study over a session

To follow: about 80 shots, each blocked shot compared with itself unblocked, for half a flight, a whole flight before the bounce, the bounce to the next hit, and the whole shot (`vision/tools/blockStudy.m`, the block-study job in the Vision tests).

## Limits

- Synthetic only. Real blocked stretches will also have worse detections just before and after them.
- A flight seen by one camera has no check on its distance from that camera except the pins. From the GoPros' side-on positions this is mild; from behind a baseline it is severe (the iPhone footage shows it: a fit that matches the picture to under a pixel can be metres off along the line of sight).
- Two flights in a row seen by one camera are pinned one to the next, so errors add up.
