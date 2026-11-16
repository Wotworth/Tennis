# Part B: active-learning labelling, design (16 Nov). Not implemented; for Chris's approval.

Replaces the "Ball check" part of section A item 13 in `docs/VISION-REQUIREMENTS.md`. That design sends crops through the cloud Worker, and the app shows a crop only. The rest of item 13 stays:
- "This looks wrong" and "Missed a shot here";
- auto-labels from flights both cameras agree on;
- the promotion rule.

## 0. Decisions needed first (conflicts with the current rules)

| # | Conflict | Options | Recommendation |
|---|---|---|---|
| B-D1 | TV-ARCH-01/04: nothing but MATLAB (and the one-time setup script) runs on the PC. A web app needs a web server. | (a) A small web server in **TypeScript** (the language the cloud Worker already uses), run by Windows at log-on, beside MATLAB. MATLAB still does all selection and training; the server only serves images and stores labels. (b) A web server written in MATLAB on its raw network sockets: possible, but it has to share MATLAB with the pipeline, so it stalls while a session processes, and is fragile. | **(a).** Amend TV-ARCH-04 to allow it. |
| B-D2 | CLAUDE.md and TV-API-06: the app talks to one host only (the Worker), plus the Claude photo retry. The Training tab must talk to the PC. | (a) Allow a second host: the closet PC, reached **only** over Tailscale, for the Training tab only. Nothing on the public internet. (b) Route through the Worker as now, which breaks "Tailscale only". | **(a).** Update CLAUDE.md and TV-API-06. |
| B-D3 | The existing "Ball check" screen (crop only, through the cloud). | Replace it with the Training tab. | Replace. |

## 1. Candidate selection (on the PC, after each session)

**Sources** (each candidate is one detection, or a predicted position, in one camera frame):
1. **Low confidence:** detector scores in the uncertain band around the acceptance threshold.
2. **Tracking lost:** the frames where a kept track ends without an event (hit, bounce, net, out of view), and the predicted position in the next frames.
3. **Rejected by geometry or physics:**
   - candidates the gate rejected close to the court of interest's edge (within 1 m);
   - "epipolar fail" points;
   - flights dropped as not physically possible.
4. **Camera conflicts:** a confident ball in one camera with nothing at the matching sight line in the other, or two candidates competing for one partner.

**Ranking by expected training value:**
- score = how uncertain the model is (closest to its threshold), × how rare that situation is in the training set so far (court position, distance, light, background type), × the source's weight (conflicts and losses highest);
- then a diversity pass: at most 5 candidates from one rally, and spread across sessions and cameras.

**Batch:** the top N, where N = `labelling.batchSize`, default 50, configurable. A new batch is made after each session, and on request.

## 2. Architecture

```
            Tailscale only (private network; nothing public)
   ┌────────────────┐         ┌────────────────────────────┐
   │ Phone (S25)    │ ──────► │ Closet PC                  │
   │ native app,    │  HTTPS  │  labelling server (TS)     │
   │ "Training" tab │ ◄────── │   - queue, batches, labels │
   └────────────────┘         │   - serves the web app     │
   ┌────────────────┐         │  MATLAB pipeline           │
   │ Tablet/laptop  │ ──────► │   - picks candidates       │
   │ browser        │ ◄────── │   - trains, evaluates      │
   └────────────────┘         └────────────────────────────┘
```

- **One backend, one label format, one queue.** Both front ends call the same API:
  - `GET /batches/next`;
  - `GET /candidates/{id}/media`;
  - `POST /labels`;
  - `POST /labels/undo`;
  - `GET /progress`;
  - `GET /models`.
- **Tailscale only:**
  - The server listens on the PC's Tailscale address only, through `tailscale serve`, which gives an HTTPS address inside the private network. Never `tailscale funnel`, which would publish it.
  - The Windows firewall blocks the port on every other network.
  - Each device is enrolled once with a token stored on the device. Lost devices are revoked in Tailscale.
- **The PC stays headless.** Everything is reached from the phone or browser.
- **Images:**
  - full frames cut from the archived footage at labelling time, as JPEG at 1920 px wide;
  - crops of 256 × 256 px from the full-resolution frame;
  - neighbouring frames (±5 by default) at 1280 px wide, with their crops.

## 3. Keeping the two front ends coupled (mandatory)

- **One written spec:** `docs/LABELLING-UI-SPEC.md` says everything the two front ends must share:
  - actions;
  - reason tags;
  - views;
  - rules (e.g. the full frame always with the crop);
  - undo;
  - progress;
  - which keyboard keys and swipes map to which action.

  Its machine-readable twin, `labelling/ui-contract.json`, lists the action IDs, tag IDs, view IDs and the label record's fields.
- **Both front ends are built from the contract:**
  - the phone app's actions and tags are generated from the JSON at build time;
  - the web app loads it.

  Adding an action means editing the contract once.
- **Parity tests,** run in CI whenever either front end, the server or the contract changes:
  - the app's unit tests check that its screen offers exactly the contract's actions, tags and views;
  - the web app's tests (a headless browser at phone-tablet and laptop sizes) check the same;
  - an API test sends each action from both front ends' code and compares the stored label records field by field;
  - any difference fails the build.
- **Platform-only changes** must be marked `platform: phone` or `platform: web` in the contract; the parity test then allows them.
- **Allowed differences:** layout (stacked or side by side) and input (swipes or keys). Behaviour and data never differ.

## 4. Offline on the phone

- **On Wi-Fi with Tailscale up,** the Training tab downloads the next batch: candidate frames, crops and the ±5 neighbours. A batch of 50 is about 100 MB at the sizes above; configurable.
- **Offline:**
  - labels are saved on the phone in a queue, and sent when the PC is reachable again;
  - the tab shows "12 labels waiting to send".
- **Conflicts:** if the same candidate was labelled on another device, the label with the later timestamp wins. The server logs both, with the device names, and the losing device shows "labelled on the laptop; kept the newer one".
  - Device clocks: the server records its own receive time too, and if a device's clock is more than 2 minutes off it warns.

## 5. Views (both front ends; no exceptions)

Every prompt shows together:
- **(a) The full frame,** zoomed out, with the candidate circled in a ring that doesn't hide the ball.
- **(b) The crop,** zoomed in, centred on the candidate.

The crop is never shown without the full frame.

**Motion:** step through, or loop, the frames before and after (default ±5, configurable), with the ring following the candidate's predicted position.

## 6. Layouts

**Phone** (S25 portrait, native, Metro/Zune style):
- The full frame (16:9, full width) above the crop (square, about 60% width), then the action bar.
- Large targets: 72 dp action buttons, reachable with the thumb in the bottom third.
- Swipe right = Yes, swipe left = No.
- A frame strip under the crop: tap to step, long-press to loop.
- No ripples, cards or Material controls (the app's design rules).

**Web** (Samsung tablet browser and laptop browser):
- The full frame and the crop side by side, both larger, with the neighbouring-frames strip below.
- Laptop keys:
  - Y = Yes, N = No, E = Ball elsewhere, 0 = No ball in frame, S = Skip/unsure;
  - ← → step frames, Space = loop, U = undo;
  - 1–5 = reason tags.
- Touch or click for everything else.
- Same look: black background, the app's font (Selawik), green accents from the app's tokens, no rounded cards or shadows.

**Tested on:**
- S25 portrait: the app's screenshot tests at 1080 × 2340, and on the phone;
- the tablet browser and a laptop browser: headless-browser tests at those sizes in CI, then on the devices.

## 7. Actions (identical on both)

| Action | Meaning | Phone | Web |
|---|---|---|---|
| Yes | The ringed object is the ball in play on my court | swipe right / button | Y |
| No | It isn't | swipe left / button | N |
| Ball elsewhere | The ball is somewhere else in the frame. Tap roughly on the full frame; a zoomed view opens there to place it exactly. | button, tap, refine | E, click, refine |
| No ball in frame | The ball isn't visible (hidden, out of view) | button | 0 |
| Skip / unsure | Come back later; not used for training | button | S |
| Undo | Undo the last action (any number of steps back within the batch) | button | U |

**Optional reason tags after a No:**
- ball on ground;
- neighbouring court;
- ball machine / basket;
- other object;
- motion blur.

One tap or key 1–5; skipping the tag is fine.

**Speed target:** a Yes or No is one gesture, and the next candidate's images are already loaded, so 50 labels in about 3–4 minutes.

## 8. Data

- **Label record:**
  - session, camera (serial), frame number and its timestamp;
  - candidate ID and its image coordinates;
  - the action;
  - for "Ball elsewhere", the corrected coordinates at full resolution;
  - the tag;
  - the device;
  - the label's time on the device and the server's receive time;
  - the batch;
  - the detector version that proposed it.
- **Stored on the PC** (`labels/labels.jsonl`, append-only, backed up with the archive). Never in Git (the footage is private).
- **Progress is per batch, on the server,** so a batch started on the phone continues on the laptop at the next unlabelled candidate.
- **Held-out test set:**
  - frozen, hand-labelled, never trained on;
  - made from the first labelled batches, about 300 frames spread over days, light and courts;
  - new situations (a new court, indoor, night) add a new frozen slice, only with Chris's OK;
  - each slice keeps its own results.

## 9. Retraining

- **When:** weekly when the PC is idle, or when Chris taps "Retrain now" (Training tab or web page).
- **Training data:** auto-labels (spec item 13), the new hand labels, and synthetic frames.
- **Targeted synthetic data:** the No-tags steer the synthetic generator. For example, many "neighbouring court" tags → more synthetic frames with balls on the next court; "motion blur" → more fast balls at long exposures. The same goes for situations where the labels show misses: against the back fence, in shadow.
- **Report after each round, in the app and on the web page:** precision, recall and track continuity (the share of in-play time the ball is tracked without a gap over 5 frames) on the held-out set, beside the previous model's.
- **Promotion:** only if precision, recall and track continuity are each no worse on every frozen slice. Otherwise the old model stays, and the report says why.

## 10. Spec changes proposed (on approval)

- **Section A item 13 "Ball check":** replaced by this design.
- **New requirements:** TV-LBL-01 to 12 (selection, architecture, parity, offline, views, layouts, actions, data, retraining).
- **TV-ARCH-04 and TV-API-06 / CLAUDE.md:** amended per B-D1 and B-D2.
- **Phase:** the web app and Training tab belong with the learned detector (TV-PH-5). Candidate selection and labels can start in TV-PH-2, so labels collect from the first real sessions.
