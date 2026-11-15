# Tennis Vision: design preview

Everything here is **synthetic**: one 90-minute singles session (428 shots, 66 rallies, 88 minutes) from `tv.synth.dataSession`. Every shot is flown with the pipeline's own flight model (gravity, drag, spin, wind), and the heart rate is made up in the Fitbit style. The data is in `data/`; the app bundles the same files as its sample session.

**Real UI** means the screenshot is the app's actual Compose code, rendered by the screenshot tests (`PreviewScreenshots.kt`) at the Galaxy S25's 1080 × 2340. **Mockup** means it is drawn for the preview only.

| Image | Kind | What it shows, and design choices |
|---|---|---|
| [01-sessions-list](screens/01-sessions-list.png) | Real UI | Sessions page. A wide green "vision" tile sits above the logged sessions: date, shots, rallies, fastest shot, and the court name in the tile label. |
| [02a-summary-before-identified](screens/02a-summary-before-identified.png) | Real UI | Session summary before "which one is you?" is answered. The question is a tile at the top; the headline tiles are session totals; players are listed as Player A and Player B. Court name, layout and camera-angle quality follow lower on the page. |
| [02b-summary-after-identified](screens/02b-summary-after-identified.png) | Real UI | The same after answering. Player A becomes "you"; the opponent stays "Player B" (never named). Headline tiles switch to your figures. |
| [03a-court-map-forehands-speed](screens/03a-court-map-forehands-speed.png) | Real UI | Court map, forehands, coloured by speed. Colours stay within the app's rules: the title gradient, deep green (slow) to yellow-green (fast). Filters are plain Metro text choices: shot type, colouring, player. |
| [03b-court-map-forehands-spin](screens/03b-court-map-forehands-spin.png) | Real UI | The same forehands coloured by spin effect (how many feet shorter than with no spin), on the same gradient. |
| [03c-court-map-serves-speed](screens/03c-court-map-serves-speed.png) | Real UI | Serves only, by speed: the service boxes fill. |
| [04-shot-card](screens/04-shot-card.png) | Real UI | One shot: side view of the real path (solid, speed colour) against the same launch with no spin (dashed), with the net marked. The caption gives the spin effect in feet; then speed, launch angle, net clearance, apex, the call with its uncertainty, spin with rpm ± sd, and confidence. |
| [05-rallies-tracer](screens/05-rallies-tracer.png) | Real UI, synthetic picture | Rallies list. Each rally has a still from its tracer clip above its line (shots, ending, fastest, length). The still is rendered by the synthetic court renderer, with the real tracer code (`tv.out.tracer`) drawing every shot's path. |
| [05b-tracer-frame-rally-02](screens/05b-tracer-frame-rally-02.jpg) | Synthetic picture | One tracer still at full size (1280 × 720), the way TV-OUT-04 will draw on real video. |
| [06-3d-replay](screens/06-3d-replay.png) | Real UI | 3D replay of rally 1, a still frame: the court in thin white lines, ball paths in yellow-green, the ball at the scrubber's time. Previous / next step between rallies; drag to orbit; the bar scrubs time. Drawn natively, no WebView. |
| [07-health](screens/07-health.png) | Real UI | Health page: heart rate over the whole session, white line, rallies shaded in tile green, gaps over a minute left empty. Below: average and highest, rallies vs between points, time in zones. All computed on the phone. |
| [08-trends](screens/08-trends.png) | Real UI, synthetic trend | Trends for the forehand: spin effect (ft shorter) and depth (ft inside the baseline) by session, with the racquet's restrings as dashed yellow-green lines labelled with tension. The trend data is made up to show strings going dead. |
| [09-which-one-is-you](screens/09-which-one-is-you.png) | Real UI, synthetic pictures | "Which one is you?": one tile per player with their picture, their figures below, and "not now". One tap relabels the session. |
| [10a-courts-list](screens/10a-courts-list.png) | Real UI | Library page with the new "courts" section (name, layout, lens mode, indoor or outdoor). The app bar gains "add court" (pin icon). |
| [10b-add-court](screens/10b-add-court.png) | Real UI | Add court: name, layout 1 or 2 in words, lens mode, indoor switch, an optional photo of the camera mounts, and a note that name and photo stay on the phone. |
| [11-launcher-tile-states-mockup](screens/11-launcher-tile-states-mockup.png) | Mockup | The launcher tile's states, highest priority first: detected session (yes/no), "1 question", new vision session stats (until opened), your cues, and the racket icon. Drawn with the tennis app's tile parts; the launcher draws its own. |
| `plots/` | MATLAB | The PC's pictures (TV-OUT-05) drawn by `vision/tools/previewPlots.m` from the same data: bounce maps by shot type, spin effect map, a rally in 3D, a side view, and speed and spin-rate histograms. |

Units throughout: mph, ft (inches for net clearance), rpm with ± uncertainty, °F.
