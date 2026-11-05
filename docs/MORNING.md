# Morning summary (overnight run, 5–6 Nov 2026)

All five phases were built, tested in the session and released, one release per phase, so you can fall back to any of them. Every decision made without you is in [DECISIONS.md](../DECISIONS.md) (rows dated 2026-11-05).

| Phase | Release | Report |
| --- | --- | --- |
| PH-1 logging, racquets, pivot title, cues first | [v0.1.3](https://github.com/Wotworth/tennis/releases/tag/v0.1.3) | [PH-1](reports/PH-1.md) |
| PH-2 sessions from your Fitbit, debug tuning | [v0.2.4](https://github.com/Wotworth/tennis/releases/tag/v0.2.4) | [PH-2](reports/PH-2.md) |
| PH-3 live tile (tennis side) | [v0.3.5](https://github.com/Wotworth/tennis/releases/tag/v0.3.5) | [PH-3](reports/PH-3.md) |
| PH-4 package photos, Claude retry | [v0.4.7](https://github.com/Wotworth/tennis/releases/tag/v0.4.7) | [PH-4](reports/PH-4.md) |
| PH-5 stats | [v0.5.8](https://github.com/Wotworth/tennis/releases/tag/v0.5.8) | [PH-5](reports/PH-5.md) |
| Launcher: tennis tile | [v0.9.153](https://github.com/Wotworth/wp-launcher/releases/tag/v0.9.153) | [launcher CHANGELOG](https://github.com/Wotworth/wp-launcher/blob/ccr-eb362149-pgs534/CHANGELOG.md) |

## What CI proved

Each tennis release: the app builds, signs with your key, passes the permission check, and passes the unit and screenshot tests (78 by PH-5). The launcher release v0.9.153 passed its 196 unit tests and its emulator smoke and end-to-end tests. Nothing has run on the phone.

## Start here

1. Install the newest tennis release (PH-5). It opens on **cues**.
2. Strings: **+** to add your racquets, then **restrung** (or the **camera** tile) to log each one's strings.
3. Settings (**…**) → **strings page**: try **grid**, **hero** and **mixed**; tell me which to keep.
4. Settings → **detected sessions**: type your birth year, tap **check now**, allow Health Connect (including background).
5. Long-press the version line at the bottom of settings → **debug** → **try a day** on a pre-injury tennis day; send me a screenshot.
6. Install the launcher release and pin **tennis** to Start.

Each report has the full test steps for its phase.

## Open items

- Your birth year (detection's threshold; defaults to 1980).
- Which strings layout to keep.
- The launcher's own session must merge wp-launcher branch `ccr-eb362149-pgs534` before its next release, or the tennis tile disappears again.
- Unknown until tested: whether Fitbit workouts reach Health Connect; the Claude retry against the live service.
