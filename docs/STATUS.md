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

Next for vision: buy the hardware; then TV-PH-0's lens calibration and trial sessions.

## Next

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

- Tennis Vision: Chris's answers of 15 Nov are in VISION-REQUIREMENTS.md section A. Open: capture mode (decided at the end of TV-PH-2), the usable crossing angle (20 deg, provisional).

## Known issues

- Text reading check (hand-started CI workflow) proves ML Kit works in the shrunk build; run it after any change to shrinking or ML Kit.

- Launcher work is on wp-launcher **main**. The launcher's other session still releases from `ccr-fa86e307-85zu7m` (it released v0.9.167, fix-8, from there on 6 Nov). Before every launcher release from main, merge that branch into main first, or the release drops its fixes. Done for v0.9.167 on 6 Nov (main 52730cf).

- Nothing has run on the phone yet.
- Wrapped secondary text lines sit close together (the Zune type roles trim line height); revisit in PH-1 if it reads badly on the phone.

## Building in a session

See docs/cloud-setup.md (the Zune player's setup script; this repo needs the same). Set `ANDROID_HOME=/opt/android-sdk` and `ROBOLECTRIC_REPO_URL` in each shell. Local check: `./gradlew :app:assembleRelease :app:testDebugUnitTest -Proborazzi.test.record=true`.
