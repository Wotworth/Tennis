# Part A: audio use and neighbouring-court rejection (audit, 16 Nov)

Chris's rules (16 Nov):
1. **No audio-only decisions.** No shot, hit, bounce or rally count ever comes from audio alone. Every audio hit candidate needs a video confirmation on Chris's court. Audio may only refine hit timing or help camera sync.
2. **Reject neighbouring-court events**, in audio and in video, and log every discarded event with its reason.
3. **Audit and tests.**

This report lists every place audio appears, every rule it breaks, and a proposed fix. **Nothing is changed until Chris approves.**

## 1. Where audio is used

| # | Where | What it does with audio | Breaks a rule? |
|---|---|---|---|
| A1 | `+tv/+rally/fromAudio.m`, called from `+tv/+pipeline/run.m` (the `rallies` stage) | Finds **rally windows** from sharp sounds in camera 1's sound track: sounds 0.3–3 s apart form a rally (at least 3 sounds), padded 1.5 s before and 2 s after, merged when less than 4 s apart. **Ball detection then runs only inside these windows.** | **Yes, two ways.** See 2.1 and 2.2. |
| A2 | Spec TV-RAL-01 | Rally first pass scores activity from fast ball candidates, racquet-hit sounds and hit cadence. | Allowed as written (video is one of its inputs), but the code (A1) implements only the sound part. |
| A3 | Spec TV-SYNC-02 (medium sync) | Says: cross-correlate the two cameras' audio envelopes, match transients, and correct each for the sound's travel time. | Allowed by rule 1 (sync), but **the code does not do this**. The code's medium sync is video only: the ball's sight lines from both cameras (`+tv/+sync/fromRays.m`, `+tv/+sync/clockLine.m`). The spec text is out of date (see Part D). |
| A4 | `+tv/+media/readAudio.m`, `+tv/+media/probe.m` | Read the sound track and its format. | No: plumbing for A1. |
| A5 | `+tv/+synth/renderAudio.m`, `writeRecording.m`, `+tv/+air/speedOfSound.m` | The synthetic footage's sound: hits and bounces, delayed by each sound's travel time to each camera. | No (test data). **Gap:** the neighbouring courts' hits are not in the sound yet (DECISIONS, 16 Nov). |
| A6 | `+tv/+testing/fakeCard.m`, `tools/makeTestCard.m` | Test cards carry a test tone. | No. |
| A7 | Hits, bounces, net, in/out (`+tv/+events/classify.m`) and shots (`+tv/+metrics/*`) | **No audio.** A hit is a sudden change of the ball's 3D velocity in a fitted flight, credited to the nearest kept player within 2.5 m (TV-EVT-01, TV-PLY-09). | No. |
| A8 | Spec "Optional ritual" (drop a ball after pressing record) and "audio on" in the camera settings | No audio processing. | No. |

So audio decides only one thing today, and it is the one the rules forbid: **where rallies are**.

## 2. Rule breaks and proposed fixes

### 2.1 Rally windows come from audio alone (breaks rule 1)
- **What happens:** footage outside an audio window is never searched for the ball. A rally that is too quiet to trigger the audio (soft balls, wind, a loud neighbouring court raising the noise floor) is lost, and video never had a say.
- **Fix:** rally windows come from **video**. The low-resolution proxy frames (LRV) or quarter-scale frames are searched for a fast ball inside Chris's court of interest (TV-ADJ-01), using the same detector and stereo gate. A window is any stretch with a ball in play on Chris's court, padded as now (1.5 s before, 2 s after, merged under 4 s). Audio may only **widen** a window at its edges, for example to catch a silent toss before the first sound. It never creates, removes or splits one.
- **Cost:** detection on the proxies runs over the whole session instead of about a quarter of it, roughly 0.5–1 h more per 2-hour session on the PC (estimate; the day-one benchmark will measure it).

### 2.2 Rally boundaries, and so the rally count, can come from audio (breaks rule 1)
- **What happens:** two of Chris's rallies are separate only if the sound track is quiet for more than 3 s between them. A neighbouring court's hits in that gap glue them into one window. `tv.metrics.rallies` makes one rally per window, so the count is wrong.
- **Fix:** each rally is cut from the **video events**: a rally starts at a serve toss or the first hit after a dead ball, and ends at the last bounce, a net or an out, followed by no hit within 3 s. Windows only say where to look.

### 2.3 Audio hit candidates
- Nothing uses audio hits today, so rule 1's video confirmation has nothing to confirm.
- **If audio is ever used to refine hit timing:** an audio onset may move a hit's time only when a video hit is already within 30 ms of it (after subtracting the sound's travel time from the ball's 3D position to the camera). Otherwise it is logged as "audio hit with no video hit" and ignored.
- **Recommendation:** don't add it. The video fit already places hits to about 1 ms (fit study: median 1.1 ms).

### 2.4 Neighbouring-court hits seen in video (rule 2)
Already handled for balls and players by TV-ADJ:
- a neighbour's ball is rejected in 3D (outside the court of interest, or mostly outside);
- a neighbour is never one of the two kept players, so no hit can be credited to them.

**Gap:** the reject log lists detections, tracks, flights and people, but not *events*. **Fix:** log every hit or bounce the event finder discards, with its reason:
- "outside court of interest";
- "no kept player within 2.5 m";
- "flight not physically possible".

### 2.5 "Near a racquet on my court"
- **Rule 1 asks for:** the ball close to a racquet. The pipeline doesn't track racquets (spec section 1: racquet and swing tracking are out of scope for v1).
- **Current stand-in:** the hit is credited to the nearest kept player whose feet are within 2.5 m of the ball at the moment of the hit (TV-PLY-09).
- **Proposal:** keep this player-distance test as the racquet stand-in for v1. Racquet detection could come with the learned detector in TV-PH-5. **Decision needed from Chris.**

### 2.6 Spec text to correct
- TV-SYNC-02 should describe what the code does (the ball's sight lines from both cameras, offset and drift per 10-minute window), not audio. See Part D.
- TV-RAL-01 should say rallies are found from video, with audio allowed only to widen a window.

## 3. Proposed tests (synthetic)

| Test | Set-up | Pass |
|---|---|---|
| T-A1 audio with no video | The default session's sound track, plus 40 extra hit and bounce sounds in the gaps between rallies (louder and quieter than Chris's), with no ball in view. | The same shots, hits, bounces and rallies as without the extra sounds: no new rally, no new hit, none merged. Each extra sound that falls outside a video window is logged "audio with no video event". |
| T-A2 neighbour hits with sounds | The adjacent-courts session (`tv.synth.adjacentScenario`), with the neighbours' hits and bounces **added to the sound track**, at the right travel times to each camera. | Zero hits, bounces or rallies credited to Chris's court from the neighbours. Chris's own shots, calls and rally count unchanged. Every discarded neighbour event is logged with its reason. |
| T-A3 glued rallies | Two of Chris's rallies 5 s apart, with neighbour hit sounds every 1.5 s in the gap. | Two rallies, not one. |
| T-A4 quiet rally | One of Chris's rallies with its sound removed. | The rally is still found, with all its shots (video only). |

The existing `adjacentTest` (TV-ADJ-08) already covers T-A2's video side. T-A2 adds the sound.

## 4. Decisions needed

1. Rallies found from video (2.1), at a cost of roughly 0.5–1 h more processing per session (estimate): **recommended**.
2. Player distance (2.5 m) as the racquet stand-in for v1 (2.5): **recommended**.
3. No audio hit-timing refinement (2.3): **recommended**.
