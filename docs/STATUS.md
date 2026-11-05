# Status

**Phase:** overnight run through PH-1 to PH-5 (Chris asleep, 5–6 Nov; he accepted PH-0). PH-1 released (v0.1.3). PH-2 built and tested; releasing as v0.2.

## Done

- Spec v0.2 with Chris's answers (docs/REQUIREMENTS.md); launcher requests (docs/LAUNCHER-REQUESTS.md), for Chris to hand to the launcher's session.
- PH-0 code: build, CI workflow, permission check (NFR-05), crash log (NFR-02), tokens and colors (VIS-01 to VIS-04), hub with five pivots and a static tile preview (NAV-01, NAV-02), settings (NAV-08), Health Connect report with share (DET-01, DET-02), privacy page.
- Chris saved the three signing secrets (5 Nov). CI run 1 (push, no secrets) stopped before publishing as designed; run 2 (manual) passed and published v0.0.2.
- In the session: release APK builds and signs with the new key; 24 unit and screenshot tests pass. Report: docs/reports/PH-0.md.
- Release key generated in the session (EC P-256, alias `tennis`). SHA-256 fingerprint:
  `C9:8E:F4:98:A8:39:C9:7F:94:5A:E3:84:6F:A4:A2:9B:29:F0:8A:D8:52:0C:DD:7F:7C:2C:5F:8B:29:D6:4B:4C`

## Next

- Overnight: PH-2 detection, PH-3 live tile, PH-4 photos, PH-5 stats, each with its own release.

- Chris shared the report for 4 Nov (no tennis: injured for the past 30 days). Findings in docs/health-connect-findings.md: Fitbit heart rate every 2–3 s; steps from both Fitbit and the phone (must not be added together); no workout records that day.
- PH-0 accepted by Chris (5 Nov).
- PH-1 (v0.3 spec: racquets, pivot title, cues first, three strings layouts): v0.1.3, docs/reports/PH-1.md.
- PH-2 (detection, debug screen, report back a year): docs/reports/PH-2.md.
- After Chris accepts PH-0: PH-1 (logging).

## Open questions

- Chris's birth year (DET-11 threshold); defaults to 1980 until he sets it.
- Does Fitbit write workouts to Health Connect? Needs a day with a Fitbit workout.

## Known issues

- Nothing has run on the phone yet.
- Wrapped secondary text lines sit close together (the Zune type roles trim line height); revisit in PH-1 if it reads badly on the phone.

## Building in a session

See docs/cloud-setup.md (the Zune player's setup script; this repo needs the same). Set `ANDROID_HOME=/opt/android-sdk` and `ROBOLECTRIC_REPO_URL` in each shell. Local check: `./gradlew :app:assembleRelease :app:testDebugUnitTest -Proborazzi.test.record=true`.
