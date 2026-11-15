# Tennis Vision, built ahead of the hardware (15 Nov)

Chris's order of 15 Nov, built without cameras or the PC. Everything is tested on GitHub on every push: MATLAB (MathWorks' action), the Worker's tests, and the app's unit and screenshot tests. Nothing has run on the closet PC or a GoPro. Every number tuned on synthetic data is listed in [VISION-RETUNE.md](../VISION-RETUNE.md).

| # | Step | State | Tested by |
|---|---|---|---|
| 1 | Placement check and fence lookup table ([TV-PH-0a](TV-PH-0a.md)) | done; provisional lens figures | MATLAB CI |
| 2 | Physics core: flight model, RK4 vs ode45, air density, court | done | MATLAB CI |
| 3 | Synthetic footage generator (TV-TST-01), and a data-level generator for long sessions | done | MATLAB CI |
| 4 | Pipeline end to end on synthetic footage | runs end to end; results below | MATLAB CI (`pipelineTest`) |
| 5 | Card import, GoPro telemetry, pairing, courts by GPS, watcher | done | MATLAB CI (fake cards, GoPro's HERO8 sample) |
| 6 | Cloudflare Worker, D1 schema, R2 (not deployed) | done | Worker CI (13 tests) |
| 7 | App vision screens, courts, trends, "which one is you?" | done, with a synthetic sample; release v0.6.18 | app CI (133 tests) |
| 8 | PC setup script | written, not run, not syntax-checked | none |

## Step 4: the pipeline against the synthetic truth

On a 26-second, two-camera synthetic session at a quarter of 4K resolution (two rallies, a changeover, an out ball, a net ball):

RESULTS

## Chris's 15 Nov additions

- **Calibration with no layout assumed.** The pose is searched all round the court from the lines alone. The court's half-turn twin is settled by both cameras agreeing on the ball and the players. The crossing angle goes into session.json, and weak zones go into the ntfy alert.
- **Courts in the app.** Name, layout, lens mode, indoor and mount photo, all on the phone. "Playing here now" labels the next session. An indoor court sends only an indoor flag, and the PC reruns from the physics stage.
- **PC uploader and answer loop.** Indoor flags and identity answers rerun only the stages they affect, then re-upload.

## Design preview

[docs/preview](../preview/README.md): the app's real screens on a synthetic 90-minute session, a launcher tile mockup, and the PC's MATLAB plots.
