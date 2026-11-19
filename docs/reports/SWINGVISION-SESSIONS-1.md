# Sessions against SwingVision 1

19 Nov 2026. Chris's plan of 18 Nov: per session, how well the found hits and bounces match SwingVision's shots within each point, and the bounce marks as weak labels. Run on the two exports already in the session, so that new sessions are only computing time. SwingVision is not the truth here: it is a second opinion.

**Status:** the 16 Apr export is done. The 25 Apr export is still computing (about 3 hours of detection); its column will be added.

## What was run

1. The overlay reader gives each export's points, shot labels and bounce marks (docs/reports/OVERLAY-READER-1.md).
2. The round-4 detector (no colour, with its first pass) runs over every frame of every point, then the tracker keeps one ball in play.
3. The ball's path is split into flights: a split stays only where no single flight under gravity and drag explains both sides. An event (a hit, a bounce or the net) lies between one flight and the next.
4. Events are compared with SwingVision's bounce marks (exact to a frame) and shot labels (which follow the hit by about a third of a second).

## How each part carries over to the GoPros

| Part | Carries over? |
| --- | --- |
| Detector and tracker | Yes: the same code. |
| "Flights first, events between them" | Yes: it is how the two-camera system finds hits and bounces, there in 3D. |
| The one-camera flight test used here | Partly: it is the Python twin of the new one-camera fit (docs/reports/ONE-CAMERA-1.md). From behind a baseline it can say whether one flight explains a path, but not where the ball is along the line of sight. |
| The scores below | No: they describe this camera position. They are the yardstick for the detector on new courts. |

## Results

| | 16 Apr export (38 points) | 25 Apr export |
| --- | --- | --- |
| Ball tracked, share of in-play frames | 80% | computing |
| SwingVision bounces | 149 | |
| Tracked ball passes within 1 m and 0.2 s | 121 (81%) | |
| An event found within 0.15 s of the bounce | 116 (78%) | |
| Event time minus mark, frames (median; 10th to 90th) | -1; -6 to +4 | |
| SwingVision shots | 207 | |
| An event found in the second before the label | 125 (60%) | |
| Label after that event, frames (median; 10th to 90th) | 20; 8 to 31 | |
| Events found against SwingVision's shots, bounces and net balls | 305 against 369 | |
| Points where the two counts agree exactly; within 1; within 2 | 9; 22; 29 of 38 | |
| Events found with no SwingVision counterpart | 57 (1.5 a point) | |
| Unclear stretches (two events may hide as one) | 67 | |

## What the 28 missed bounces show

For the 28 bounces the tracked ball does not pass:

- **27 had a moving spot proposed at the place and time.** The first step is not what loses the ball.
- **15 had a spot the classifier scored above 0.3.** So for about half, the classifier saw it and the tracker chose something else as the ball in play.

## Weak labels, dry run

Around each bounce mark the search looks for a smooth path among all proposals, whatever their scores, that passes the mark within its uncertainty and moves like a ball.

- 121 of 149 marks: the tracker's own ball (4,525 ball examples near them; these add little, the classifier already scores them).
- **14 more marks recovered** by the search (504 ball examples). Coverage goes from 81% to 91%.
- 14 marks: nothing found.
- Only 25 of the 504 recovered examples were scored under 0.5 by the classifier. The rest were seen but not chosen. So on this footage the gain is in the tracker's choice of which path is the ball in play, more than in the classifier. This export was part of the training footage; a new court should show more classifier misses.
- The guard holds: nothing on or near these paths can become a "not a ball" example.

## Reading the event numbers

- **Bounces: about 4 in 5 are found as events, within a few frames.**
- **Hits: about 3 in 5.** From behind the baseline a hit by the near player happens against the player's own body in the picture, and many flights between a bounce and the next hit are shorter than the 8 detections a flight needs here. The 67 unclear stretches are mostly a bounce and a hit close together.
- **This does not carry over as a number.** With two cameras at the side, a hit is a change of the ball's 3D velocity seen across the view, and the pipeline's synthetic tests find every hit within 30 ms.
- **SwingVision has gaps too:** 45 of its shots on this export have no bounce mark, and 57 events found here have none of its shots or marks beside them. Nobody has checked those 57 by eye yet.

## Next

1. The 25 Apr export's column.
2. A by-eye check of 20 disagreements (events with no SwingVision counterpart, and bounces missed), so the yardstick itself is trusted.
3. The new sessions: the same run on each, then training on the weak labels from courts kept for training, and the scores above on courts kept for testing.
