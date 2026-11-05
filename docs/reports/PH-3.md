# PH-3 report: live tile on the WP launcher

Release: [v0.3.5](https://github.com/Wotworth/tennis/releases/tag/v0.3.5) (tag `ph-3`; CI passed). Launcher release: tag `tennis-tile` in Wotworth/wp-launcher (see the morning summary).

## Done

| IDs | What |
| --- | --- |
| TIL-01 | Provider `io.github.wotworth.tennis.tile` with one row: `Tennis?` and the window when a session is waiting; otherwise the hours on the strings of the racquet you played last ("hours · Black Blade #1" when you have several); empty before any restring. Answers only the launcher. |
| TIL-02 | Every change (session, restring, racquet, proposal found, answered or expired) tells the launcher at once. |
| TIL-10, TIL-11 | Tapping the tile opens the app at the waiting session's Yes/No prompt, or at home. |
| Launcher | Built in Wotworth/wp-launcher, branch `ccr-eb362149-pgs534`: the tennis app's tile uses the Battery tile's big-number layout; settings → tiles → Live tiles → "Tennis tile shows hours and found sessions" (on). Launcher unit tests: 196 pass, 5 of them new. |

Tests: 64 pass in the tennis app (5 new: the row's rules and the provider answering).

## What remains

- The launcher's own session must merge `ccr-eb362149-pgs534` before its next release (docs/LAUNCHER-REQUESTS.md says so at the top). Until then, a launcher release from its usual branch drops the tile.
- Nothing has run on the phone.

## Test steps for Chris

1. Install this tennis release, and the launcher release named in the morning summary (tag `tennis-tile`).
2. Pin the **tennis** app to Start (medium or wide). It should show your hours, e.g. **13** over "hours · Black Blade #1".
3. Log a session in the tennis app, press Home: the number changes.
4. When a found session is waiting, the tile shows **Tennis?** and the time; tap it: the Yes/No prompt opens.
5. Settings → tiles → Live tiles → "Tennis tile shows hours and found sessions" turns it off and on.
