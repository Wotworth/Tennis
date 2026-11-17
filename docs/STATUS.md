# Status

**Phase:** TV-PH-0 (Tennis Vision, docs/VISION-REQUIREMENTS.md), building ahead without hardware (Chris, 15 Nov). The app's last accepted phase: tile-4 (accepted 15 Nov).

## Done

- Spec v0.2 with Chris's answers (docs/REQUIREMENTS.md); launcher requests (docs/LAUNCHER-REQUESTS.md), for Chris to hand to the launcher's session.
- PH-0 code: build, CI workflow, permission check (NFR-05), crash log (NFR-02), tokens and colors (VIS-01 to VIS-04), hub with five pivots and a static tile preview (NAV-01, NAV-02), settings (NAV-08), Health Connect report with share (DET-01, DET-02), privacy page.
- Chris saved the three signing secrets (5 Nov). CI run 1 (push, no secrets) stopped before publishing as designed; run 2 (manual) passed and published v0.0.2.
- In the session: release APK builds and signs with the new key; 24 unit and screenshot tests pass. Report: docs/reports/PH-0.md.
- Release key generated in the session (EC P-256, alias `tennis`). SHA-256 fingerprint:
  `C9:8E:F4:98:A8:39:C9:7F:94:5A:E3:84:6F:A4:A2:9B:29:F0:8A:D8:52:0C:DD:7F:7C:2C:5F:8B:29:D6:4B:4C`

## Tennis Vision (TV-PH-0, building ahead without hardware)

Built and tested without cameras (details: docs/reports/TV-BUILD-1.md):
1. Placement check and fence lookup table (docs/reports/TV-PH-0a.md), provisional lens figures.
2. Physics core: flight model, RK4 vs ode45, air density, court model.
3. Synthetic footage generator (TV-TST-01).
4. Pipeline end to end on synthetic footage: layout-free calibration with symmetry resolved by agreement, crossing-angle report and alert, timing, detection (GPU with CPU fallback), tracks, flights, wind and drag, events, players and identity, metrics, outputs.
5. Card import, telemetry (GoPro HERO8 sample), pairing, courts.
6. Cloud Worker, D1 schema, R2 (not deployed).
7. App vision screens with a bundled sample session.
8. PC setup script (written, not run, not syntax-checked).
9. Courts (Chris, 15 Nov): app courts (name, layout, lens mode, indoor, mount photo), "playing here now" labels the next vision session; indoor flag to the Worker; PC reruns from physics, re-uploads. Names and photos stay on the phone.
Retune list: docs/VISION-RETUNE.md.

10. Design preview (docs/preview): the app's vision screens on a synthetic 90-minute session (release v0.6.18 "vision-preview" carries them), a launcher tile mockup, and the PC's MATLAB plots. Suggested spec changes: docs/preview/SUGGESTED-SPEC-CHANGES.md.

11. Detector improvement loop, spin kinds and opponents (Chris, 15 Nov; section A items 13-15): Ball check (PC picks and crops, app screen), "this looks wrong", "missed a shot here", test set and auto-labels kept apart, retraining (GPU or CPU) with promotion only when recall and precision don't drop, weekly message; opponents prompt, list and pages (in memory until the cloud exists); spin shown by kind; tile "N frames to check" at the lowest priority.

MATLAB tests: all 85 pass in CI (run 43867464023, 16 Nov): pipeline test 9 of 9 shots, 9 of 9 calls, no phantom hits. Earlier: all passed (67 of 67, including the end-to-end test on synthetic footage and the learning loop); results in docs/reports/TV-BUILD-1.md. Watch on real footage: camera 2's readout (measure it with the flicker method, TV-SYNC-06).

Outside-check review (16 Nov), items 1-10: health data confirmed never built in the cloud and removed from the spec; one host (the Worker streams R2, already built); court frame from geometry with a swapped-camera test; detector data kept forever (TV-OPS-07, about 0.65 TB a year); layout 2 placement (docs/reports/TV-PH-0a.md); doubles cut from v1; synthetic truth now flies unlike the fitter, with a 400-shot fit study as its own CI job; readout time measured from a flickering lamp (TV-SYNC-06); the 11 cm bounce traced to detections that were not the flying ball, fixed by a 6 px outlier cut and lift priors. Fit study numbers: see docs/reports/TV-BUILD-1.md once CI finishes.

Design v2 (Chris, 16 Nov; VIS-09 amends VIS-04 to VIS-08): variations of the court map, shot card and trends, with player colours (opponent cobalt blue), in docs/preview/v2. Waiting for Chris's pick; then apply to the vision screens, then cues, racquets, sessions and library, and update the screenshot tests.

TV-OPS-04 / AC-12 (16 Nov): processing limit 12 h per 2-hour session (13 h cards to app); 6 h is a goal; processing time per mode feeds the TV-PH-2 capture-mode choice.

Overnight 16 Nov (Chris's items 1-8):
- Closet PC ready (TV-HW-01 to 08): GPU 200 W cap at log-on, USB port plan with a slow-reader alert, archive D: (internal or USB), heat log each minute with slow-down above 90/80 °C and weekly peaks, RGB off, staging check, Windows 11 Pro before Remote Desktop. Setup script untested (no Windows here).
- tools/benchmarkPC.m (4K120 capped and uncapped, 4K240; each stage timed, projected to 2 h against 12 h). Its CI smoke run crashed on the reel step (fixed, rerunning).
- docs/USER-MANUAL.md (section 2.1), docs/USER-MANUAL.md (section 2.3) (token steps; nothing deployed).
- Error budget: docs/reports/TV-ERROR-BUDGET.md. Calibration dominates positions; frame rate dominates speed and spin (240 fps passes AC-07).
- Ingest fault injection (tests pass), toolbox guard test, docs/READING-GUIDE.md.
- Fit study (400 shots) found that camera 2's clock drift was never estimated: only the first 15 minutes of a 90-minute session were reconstructed. Fixed (tv.sync.clockLine, offset and drift per 10-minute window). Rerun: 361 of 366 found, bounce 1.6 cm, calls all right; speed (66% within 2 mph), spin effect (15 cm) and rpm (13%) fail at 120 fps, as the error budget predicts (docs/reports/TV-BUILD-1.md). A last flight fix (junk parts rejoin a neighbour) came after that run; the fit study is rerunning on it.

Adjacent courts (Chris 16 Nov, TV-ADJ-01 to 08, AC-14 to AC-16): court of interest, stereo pairing, volume gate, track and player filters, reject log (CSV and HTML, uploaded with the session; counts on the app's session page). Gate unit test passes locally; the full adjacent-courts footage test (adjacentTest) was first run in CI on 16 Nov — result to check.

Spoof session (Chris 16 Nov): v0.6.22 bundles a spoof vision session with no even numbers on the vision screens (app/spoof/make_spoof_session.py; SpoofOddNumbersTest reads every vision screen). Exceptions: rpm (rounded to 10), the court map scale labels, the heart-rate grid and zone names, and zone minutes (from the phone's birth year).

Chris's six-part prompt (16 Nov), delivered for approval, nothing implemented:
- A: docs/reports/AUDIO-AUDIT.md (rally windows come from audio alone: proposed video-based rallies; tests T-A1 to T-A4).
- B: docs/design/LABELLING.md (Training tab + web app on the PC over Tailscale; decisions B-D1 to B-D3 needed).
- C: docs/design/CALIBRATION.md (net tape must go from calibration; post confidence check; cross-check).
- D: docs/reports/SYNC-QA.md (answers; recommends the ball drop, not the clap).
- E: docs/USER-MANUAL.md (the single manual; DAY-ONE and CLOUDFLARE-SETUP folded in).
- F: docs/design/RACQUETS.md (answers + switch design; the prompt was cut off: rest of Part F needed).

Hero 7 ball-machine trial (Chris 16 Nov): proposed, not started. One GoPro Hero 7 Black on a ball machine, run in MATLAB Online, as a preliminary test of detection, tracking, bounce positions and a one-camera speed estimate. Waiting for Chris's answers on capture mode and the plan.

Footage tests (Chris 17 Nov): two SwingVision "included rallies" exports from Chris's iPhone (25 Apr 2025, 7:51 of rallies, pickleball tape, two courts in play behind; 16 Apr 2025, 5:41, a fenced court), kept in the session only. A one-camera pipeline (tv.pipeline.runSingle) runs on them and the results are in the app as "footage tests" (both bundled). Final numbers (hand checks): court 20 px and 6 px from Chris's drawings; ball found when visible 13 of 15 and 17 of 24; tracked spots that are the ball 6 of 26 (video 1: courts behind, far player, swung racquets) and 15 of 17; bounces 6 of 16 and 13 of 16 real. Added on 17 Nov: steadying (tv.calib.steady, TV-CAL-14), exact volume mask (TV-DET-02), still-ball rule (tv.track.dropStill), racquet rule (tv.track.dropAtPlayer, Chris's option 1; people against each clip's own empty court), steered search along tracks (tv.track.follow, Chris's suggestion), bounce skips for hits, net and repeats, bounces from the detector's own points. Report: docs/reports/FOOTAGE-TEST-1.md. Chris allowed the frames (players pixelated) in the public repo for these two videos only. Known: video 1's player placing still uses the whole-video empty court (fails in the evening light); adjacentTest false negatives 17.9% (14.4% before the mask fix), parked.

Adjacent courts (AC-14 to 16) on CI 17 Nov: false positives 0% (limit 0.5%), swaps 0 (limit 0), **false negatives 13.5% (limit 2%)**, and shots found under 95%. Mostly "overlaps a better track" (195 of 402). Being fixed; stage files now printed by CI.

Next for vision: Chris reviews the preview; then the hardware (TV-PH-0's lens calibration and trial sessions). The launcher needs the new "checks" tile state (LAUNCHER-REQUESTS.md), not built.

## Next

- Design v2 (VIS-09): vision pages done with Chris's 17 Nov feedback (tabs summary/court/3D/health, rally pages with replay, wide court colour scale, swipeable tab names; reports DESIGN-V2-1, DESIGN-V2-2, release v0.6.28). App-wide: shared parts done (segments, square buttons, labelled app bar). Then (v0.6.33): court map pinch-zoom; summary key figures (accuracy, serves, topspin, speed) against all earlier sessions and the last ten; session trends tab with a rolling ten-session average; iPhone footage tests removed from the app. Next: whichever hub pages Chris names after testing v0.6.28.

- Chris tests the overnight builds (one release per phase; each report has numbered steps) and picks a strings layout (grid, hero, mixed).
- Chris sets his birth year, and runs debug → try a day on a pre-injury tennis day; tune detection from it.
- Chris tests update 1 (docs/reports/UPDATE-1.md).

- Chris shared the report for 4 Nov (no tennis: injured for the past 30 days). Findings in docs/health-connect-findings.md: Fitbit heart rate every 2–3 s; steps from both Fitbit and the phone (must not be added together); no workout records that day.
- PH-0 accepted by Chris (5 Nov).
- PH-1 (v0.3 spec: racquets, pivot title, cues first, three strings layouts): v0.1.3, docs/reports/PH-1.md.
- PH-2 (detection, debug screen, report back a year): v0.2.4, docs/reports/PH-2.md.
- PH-3 (live tile): v0.3.5. Tennis provider here; launcher side on Wotworth/wp-launcher branch `ccr-eb362149-pgs534`. docs/reports/PH-3.md.
- PH-4 (photos, on-phone reading, Claude retry, API key): docs/reports/PH-4.md.
- PH-5 (stats; cues were done in PH-1): docs/reports/PH-5.md.
- After Chris accepts PH-0: PH-1 (logging).

## Open questions

- Purchase: Claude recommends buying the two cameras now and the PC later (17 Nov); Chris to decide.

- Hero 7 trial: capture mode (1080p120 H.264 vs 2.7K120 HEVC, after a 10-second MATLAB Online test clip), whether a radar gun is available, MATLAB Online access on his licence.

- **MATLAB tests once the repository is private (Chris, 16 Nov; nothing changed yet).** Options:
  1. Keep the repository public until the closet PC runs, then a self-hosted GitHub runner on the PC, using his MATLAB Home licence (personal use). Recommended. Needs from Chris: the PC; one runner registration token from GitHub settings (Claude Code on the PC does the rest); tests then run only while the PC is on, scheduled away from overnight processing.
  2. Apply for MathWorks' batch licensing token for GitHub-hosted runners. Needs his MathWorks account and an application; it is a pilot and may not cover a Home licence.
  3. Stay public for good. Needs nothing; the code holds no secrets or locations.
  4. Meanwhile, if he goes private before the PC: GNU Octave on GitHub's runners (free minutes, no licence) runs most tests; the parts that need MATLAB-only toolboxes (learned detector training, some vision functions) would wait for option 1.

- Tennis Vision: Chris's answers of 15 Nov are in VISION-REQUIREMENTS.md section A. Open: capture mode (decided at the end of TV-PH-2), the usable crossing angle (20 deg, provisional).

## Known issues

- Text reading check (hand-started CI workflow) proves ML Kit works in the shrunk build; run it after any change to shrinking or ML Kit.

- Launcher work is on wp-launcher **main**. The launcher's other session still releases from `ccr-fa86e307-85zu7m` (it released v0.9.167, fix-8, from there on 6 Nov). Before every launcher release from main, merge that branch into main first, or the release drops its fixes. Done for v0.9.167 on 6 Nov (main 52730cf).

- Nothing has run on the phone yet.
- Wrapped secondary text lines sit close together (the Zune type roles trim line height); revisit in PH-1 if it reads badly on the phone.

## Building in a session

See docs/cloud-setup.md (the Zune player's setup script; this repo needs the same). Set `ANDROID_HOME=/opt/android-sdk` and `ROBOLECTRIC_REPO_URL` in each shell. Local check: `./gradlew :app:assembleRelease :app:testDebugUnitTest -Proborazzi.test.record=true`.
