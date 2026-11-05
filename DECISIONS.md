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
