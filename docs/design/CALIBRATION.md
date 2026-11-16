# Part C: camera calibration, design (16 Nov). Not implemented; for Chris's approval.

Reviews the existing calibration requirements (`docs/VISION-REQUIREMENTS.md` section 3) against Chris's 16 Nov requirements. Proposes the updates. The checkerboard guide (C2) is in the user manual (`docs/USER-MANUAL.md`, section 4).

## 1. What is already covered, what changes, what conflicts

| Chris's requirement | Existing spec / code | Status |
|---|---|---|
| C1 Lens calibration once per camera, checkerboard, off court | TV-CAL-01 (about 60 checkerboard views, fisheye vs standard model, keep the better, RMS ≤ 0.5 px), TV-CAL-02 (stored per serial and mode, alert if missing) | **Covered.** Change: "mode" must name resolution, frame rate, lens mode (field of view) and stabilisation, not just a mode name. |
| C1 Flag a missing calibration in the app, never use the wrong one | TV-CAL-02: alert by phone message, and "the session waits" | **Partly.** Add: the session shows in the app as "waiting: no lens calibration for camera X in 4K120 Wide", and the PC never falls back to another mode's calibration. |
| C1 Nothing placed on the court | Nothing in the spec places a target on court. The spec's "optional ritual" (ball drop) is not a target. | **Covered.** |
| C3 Position from court lines every session, automatically | TV-CAL-10/11 (lines from a median background frame, fitted to the court model), TV-CAL-13 (line error ≤ 1 px), TV-CAL-14 (re-solve every 5 min) | **Covered** (built and tested on synthetic footage). |
| C3 Net posts as height (Z) reference | TV-CAL-12 says "the tops of the net posts (1.07 m) and the net tape at the centre (0.914 m)". **Code:** uses the whole net tape (`+tv/+calib/modelPoints.m`), and no posts. | **Conflict.** Chris: never use the net or its centre height. Remove the net tape from TV-CAL-12 and from the code; add post detection (C3a). |
| C3 No player height | Player height is used only for identity (TV-PLY-05), never for calibration. The symmetry choice (`resolveSymmetry.m`) uses where people stand, not their height. | **Covered.** Wording added to make it explicit. |
| C3 Configurable reference dimensions | Court dimensions are fixed constants in `+tv/+court/constants.m`. | **New:** a court block in the config (lengths, widths, service line, post height and post distance outside the doubles line), regulation by default, overridable per court. |
| C3a Post confidence check | Not in the spec or code. | **New** (section 3). |
| C4 Reprojection error per camera | TV-CAL-13, in session.json. | **Covered** for lines. Add posts. |
| C4 Two-camera cross-check | Not in the spec. | **New** (section 4). |
| C4 Flag poor calibration in the app, naming the reference at fault | TV-CAL-15 posts an alert only when calibration fails outright. | **New** (section 4). |

## 2. Lens calibration (C1): changes to TV-CAL-01/02

- **Key:** `serial + resolution + frame rate + lens mode + stabilisation`, e.g. `C3501325000001_3840x2160_119.88_Wide_HSoff`. Read from each file's metadata on import (GPMF and the MP4 header). If the metadata doesn't say the lens mode or stabilisation, the session is flagged "lens settings unknown", not guessed.
- **Missing calibration:**
  - The session is imported and archived as normal, then waits.
  - The app shows it as "waiting for lens calibration: camera 2, 4K120, Wide".
  - The phone gets one message.
  - Processing resumes on its own once the calibration exists.
  - The PC never uses a different mode's calibration.
- **Pass:**
  - RMS reprojection error ≤ 0.5 px;
  - at least 40 accepted views;
  - corner coverage: each of the 9 tiles of a 3 × 3 grid over the image has at least 3 views;
  - the outer ring of tiles covered at 80% or more.
- **Output:**
  - stored per key;
  - a one-page report: the coverage map, the error per view, and the distortion model chosen.
- **Submission:** described in the manual. The card goes into a reader as after any session. The PC recognises a checkerboard clip by itself (TV-ING-14: a board found in at least 30% of sampled frames) and runs the calibration instead of a session. The result arrives as a phone message: "Camera 1 calibrated for 4K120 Wide: 0.31 px, passed", or the reason it failed.

## 3. Per-session position from lines and posts (C3, C3a)

### 3.1 References
- **Court lines** (main): every painted line, at the configured court dimensions.
- **Net posts** (vertical): each post is a vertical segment.
  - Base on the ground at y = ±(half doubles width + post distance); regulation post distance is 0.914 m.
  - Top at the configured post height (regulation 1.07 m).
  - **Lean:** the post may lean up to 3° away from the net, a configurable tolerance. It is modelled as a segment from the base with a small unknown lean angle, fitted, not assumed vertical.
- **Not used:** the net, its tape, its centre height, player height.

### 3.2 Finding a post and its confidence (each post, each camera)
1. **Where to look.** From the lines-only pose, project the post's expected segment, base to top. Search a band ±0.3 m around it in the background frame (the median over a quiet minute), which removes passing players.
2. **What to find.** A vertical pair of edges of near-constant width (the post's two sides), its foot meeting the ground near the expected base, and its top end.
3. **Confidence:** each sub-score is 0–1, and the post's confidence is the lowest.
   - **Base:** the foot is visible and meets the ground within 5 cm of the expected base.
   - **Top:** the edge pair ends sharply. The top is the same colour and width as the post below it. Nothing continues above the expected height: a scorekeeper tube, a towel or a hopper shows up as a change of width or colour, or as a continuation.
   - **Height:** the measured height, along the leaning post, is within ±3 cm of the configured height (tolerance configurable).
   - **Steady:** the top found in each 5-minute background frame stays within 1 px. A towel added or removed mid-session fails this.
   - **Unobstructed:** no person box from the player detector overlaps the post in the background frames used.
4. **Use:** a post is a height reference only if its confidence is ≥ 0.8 (configurable) in that camera **and** its height passes. A post can pass in one camera and fail in the other; each camera uses only its own passing posts.
5. **Fit:** the posts' base and top join the line pixels in the pose fit (TV-CAL-11) as point constraints, with the lean angle as an extra unknown per post.
6. **Neither post passes:** the pose comes from the lines alone, and session.json records `heightReference: "none"` with each post's reason.

### 3.3 In the app
- On the session's summary, under **court**:
  - "camera height reference: left post ✓, right post ✗ top obstructed";
  - or "no height reference (both posts obstructed): positions from the lines alone".
- The reasons, in plain words:
  - "top obstructed";
  - "base hidden";
  - "height 1.21 m, expected 1.07 m";
  - "moved during the session";
  - "a player stood in front".

### 3.4 Synthetic tests (all must still calibrate)

| Case | Expected |
|---|---|
| Both posts clear | Both used; pose within 5 cm and 0.2° of truth. |
| Scorekeeper tube on one post (0.4 m tube on top) | That post rejected, "top obstructed"; the other used. |
| Towel draped over one post's top half | Rejected, "top obstructed". |
| Player standing in front of one post through most of the session | Rejected, "a player stood in front" (or used, if the median background frame clears them; either is acceptable if the reason is logged). |
| Both posts obstructed | Lines only, `heightReference: "none"`; pose still within the lines-only accuracy. |
| Posts leaning 2° away from the net | Both used; lean recovered within 0.5°. |
| A court whose posts are 1.10 m (configured) | Used with the configured height; height check passes. |

## 4. Accuracy checks (C4)

- **Per camera:** RMS reprojection error of the line pixels and the accepted post points. Target ≤ 1.0 px (TV-CAL-13).
- **Between cameras:**
  - triangulate the court's line intersections (singles and doubles corners, service T's, centre marks) and the tops of accepted posts from both cameras;
  - compare them with their known 3D positions;
  - report the median and maximum error in cm. Target: median ≤ 2 cm, maximum ≤ 5 cm (to be confirmed on real courts).
- **Flag:** if a camera's RMS is over 1.0 px, or the cross-check over target, the session shows "poorly calibrated" in the app, naming the worst reference, e.g.:
  - "camera 2: far baseline poorly fitted (3.4 px)";
  - "right post height off by 6 cm".
- Speeds and positions from a flagged session are shown, but marked as less certain.

## 5. Spec changes proposed (on approval)

- **TV-CAL-01/02:** the mode key; app flag; never fall back.
- **TV-CAL-12:** posts with lean and the confidence check; net and centre height removed.
- **New:**
  - TV-CAL-16, configurable court references;
  - TV-CAL-17, post confidence;
  - TV-CAL-18, two-camera cross-check;
  - TV-CAL-19, app display.
- **Code:** remove the net tape from `modelPoints.m`. Add the post finder, the confidence check and the cross-check, with the tests in 3.4.
