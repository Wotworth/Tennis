# Decisions

Choices made where the spec was silent, or changed by Chris. Newest last.

| Date | IDs | Decision | Reason |
| --- | --- | --- | --- |
| 2026-11-05 | Q1–Q11 | Chris answered section 16: defaults, except cues as a fifth pivot (the warmup view), `claude-sonnet-5-5` for the photo retry, and hours tracked per racquet. Spec v0.2. | Chris, 5 Nov. |
| 2026-11-05 | PLT-03 | Copied from the Zune player at f2d9237: build workflow, Gradle signing code, crash log, tilt and tap detection, the pivot pager, the giant gradient title, type roles and Selawik fonts. The tokens file keeps only what this app uses. | Spec section 3; same look with no shared module. |
| 2026-11-05 | PLT-03 | The release key is EC P-256 (not RSA) so its base64 text is short enough to paste from a tablet (about 1,400 characters). Android accepts EC signatures on every version this app supports. | Chris pastes the secrets by hand. |
| 2026-11-05 | VIS-03 | Gradient end color `#2B8A3E`, not the drafted `#1F7A3A`, which is 3.9:1 on black and fails VIS-03's 4.5:1. A unit test checks both stops. | VIS-03. |
| 2026-11-05 | VIS-06, Q2 | App icon: the word "tennis" in Selawik Semilight, traced to a vector, white on the tile green. Fluent has no tennis glyph (its "sport" glyph is a ball and an American football), and VIS-06 forbids drawing one without approval. | VIS-06. |
| 2026-11-05 | NAV-02 | The four strings-pivot action tiles sit two per row (log session, restrung / camera, warmup) instead of three in a row, so the labels fit at the Zune label size. Warmup opens the cues pivot. | Labels didn't fit in a third of the width. |
| 2026-11-05 | NAV-08 | Settings opens from a Windows Phone app-bar "…" at the bottom right of the hub. | NAV-08 names the app bar's "…". |
| 2026-11-05 | DET-01 | The report reads only on demand, one local calendar day at a time (up to 30 days back, *tunable*), and asks for READ_HEALTH_DATA_HISTORY too, so days before access was first given can be read. | DET-01 needs a day Chris played. |
| 2026-11-05 | NFR-05 | Permission allowlist check instead of the Zune player's no-INTERNET check, since this app will need INTERNET in PH-4. AndroidX's own DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION is on the list. | PHO-23. |
| 2026-11-05 | NAV-01 | Overnight run (Chris asleep, asked for decisions to be logged here). Title: option a, the Windows Phone pivot. The current page's header carries the gradient; the small "TENNIS" title is white, as WP apps' titles are. Option a needs no animation to look deliberate on a cold launch. | Chris's first preference; reads as "swipe for more". |
| 2026-11-05 | NAV-01 | Pivot order cues, strings, sessions, stats, library; the swipe wraps around as WP pivots do. Returning from another page comes back to the pivot you left. | Chris: open on cues, the rest to its right. |
| 2026-11-05 | RAC-03 | A session with two racquets gives each half its time (not the full time each). | String wear follows time played with that racquet. |
| 2026-11-05 | STR-05 | A session on the day of a restring counts for the new strings. | People restring before playing far more often than after. |
| 2026-11-05 | NAV-02 | Three strings-page layouts built (grid, hero, mixed), switchable in settings → strings page. Default: grid. Camera tile hidden until PH-4. Small tiles carry a glyph only (WP small tiles had no label); small number tiles carry a tiny label. | Chris asked for two or three variations to choose from. |
| 2026-11-05 | NAV-07 | Forms use the Windows Phone dark-theme text box (light grey, white with a green border while typing), the WP toggle switch, earlier/later/today for dates (no Material date picker), and lowercase choice rows for racquet, feel and length. Fields changed from the pre-filled restring show "· changed" in their label (STR-03), since a second accent colour would break VIS-08. | Metro look; VIS-08. |
| 2026-11-05 | NAV-08 | The application bar is solid #1F1F1F (WP dark theme), with round glyph buttons per page (add on cues, sessions and library; save, cancel, delete on forms) and "…" for settings. | A transparent bar overlapped list text. |
| 2026-11-05 | CUE-02 | Cue reorder, pin and delete are in a long-press menu (move up / move down) rather than drag handles. Built in PH-1, not PH-5, since cues is the first page. | Reliable on touch; WP context-menu idiom. |
| 2026-11-05 | DAT-01 | The whole schema (including proposals and cues) is created in PH-1, so later phases need no database migration. Deleting a racquet deletes its restrings; its sessions stay, without it. | DAT-04; fewer upgrade risks. |
| 2026-11-05 | NFR-05 | Allowed WAKE_LOCK, RECEIVE_BOOT_COMPLETED and ACCESS_NETWORK_STATE, which WorkManager needs for DET-20's background check; FOREGROUND_SERVICE is stripped from the manifest (never used). Still no INTERNET. | The permission check caught them; each has a reason in ci/allowed-permissions.txt. |
