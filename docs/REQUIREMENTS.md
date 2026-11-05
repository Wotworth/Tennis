# Tennis String Log — Requirements

v0.3, 5 November 2026 (Chris, after accepting PH-0): the app opens on cues; several racquets with their own strings and hours (section 5a); the Windows Phone pivot title instead of the clipped giant title; a richer strings page. v0.2, 5 November 2026: Chris's answers to section 16 (defaults, except cues as a fifth pivot, Sonnet for the photo retry, and hours tracked per racquet). v0.1, 4 November 2026: written by Claude from Chris's brief, after reading the wp-launcher code (tag v0.9.150) and the Zune player (main at `f2d9237`).

## 0 How to use this document

This spec is the single source of truth for a personal Android app that logs tennis string jobs and sessions on Chris's Galaxy S25, in the Zune / Windows Phone (Metro) style of his Zune player. Build it one phase at a time (section 14); each phase ends with an installable APK and a short report.

**Priority keywords.** **MUST**: required for the phase to pass. **SHOULD**: expected; if skipped, say why in the phase report. **COULD**: only when Chris asks later.

**Requirement IDs.** Prefixes: SCP scope, RAC racquets, PLT platform, VIS visuals, NAV screens, STR string jobs, SES sessions, DET detection, TIL live tile, STA stats, CUE swing cues, PHO photos, DAT data, NFR non-functional, PH phases. Cite IDs in commits and reports.

**Tunable values.** Every number marked *tunable* is a named constant in one tokens file, `TennisTokens.kt`, never inline.

**Permissions.** NFR-05: CI fails if the release manifest declares a permission not listed in `ci/allowed-permissions.txt`; INTERNET is added to it only in PH-4 (PHO-23).

**When the spec is silent or wrong.** (1) If something is unspecified, choose what a Windows Phone app would do, implement it, and log it in `DECISIONS.md` (date, ID, choice, reason). (2) If a requirement conflicts with Android or another requirement, stop and ask Chris. (3) Add nothing the spec doesn't list: no accounts, analytics, ads, cloud sync or reminders.

**Cost discipline.** Chris pays for compute and reviews from his phone. Keep each change to the current phase, and don't regenerate files that already pass.

## 1 Purpose and scope

An Android app, for one person on one phone, never published, installed by sideloading from GitHub release pages. It replaces a notepad for logging string jobs and tennis sessions, and must be clearly easier to read and faster to use than one.

| ID | Goal |
| --- | --- |
| SCP-01 | Logging a restring or a session takes one or two taps in the common case |
| SCP-02 | The look of Chris's Zune player (fonts, gradient titles, pivots, motion), recoloured for tennis |
| SCP-03 | Sessions found automatically from Fitbit data, always confirmed by Chris, never logged silently |
| SCP-04 | Hours on the current strings visible at a glance, in the app and on the launcher tile |
| SCP-05 | All data on the phone, with a file backup |

**In scope.** SCP-10 String jobs, sessions, stats, swing cues, string library, package photos with text recognition, the live tile, JSON export/import.

**Out of scope.** SCP-20 Reminders, nudges or notifications of any kind (Chris restrings when the strings feel flat). SCP-21 Cloud sync, accounts, sharing. SCP-22 Wear OS, widgets, tablet and landscape layouts. SCP-23 Any network use except the one Claude request in PHO-20.

## 2 Platform, toolchain and delivery

- PLT-01 Kotlin, Jetpack Compose, min SDK 34, target the newest SDK the Zune player targets. Package `io.github.wotworth.tennis` (same prefix as the launcher and the Zune player).
- PLT-02 A new GitHub repository (proposed `Wotworth/tennis`, Q1). Same delivery as the Zune player: CI on main builds a signed release APK and publishes a GitHub release; `versionCode` is the workflow run number.
- PLT-03 Reuse the Zune player's workflow file, Gradle signing code, crash log and cloud-setup notes (its PLT-10 to PLT-23, NFR-20), copied into this repo. This app gets its own new release key, stored as the same three repository secrets; Chris keeps a copy outside GitHub. Never commit the key.
- PLT-04 Room database for app data; WorkManager for the background detection check (DET-20).
- PLT-05 Unit tests and JVM screenshot tests (Roborazzi or the Zune player's equivalent) run in CI; the phase report shows the screenshots.

## 3 Visual system

Reuse, by copying source files from the Zune player (`ZuneTokens.kt`, the font files, the giant-title and pivot components, the motion constants), then retune here. Copied code keeps a header comment naming its Zune source file and commit.

- VIS-01 Selawik fonts (OFL, license file included), the Zune player's type ramp and letter spacing. Large type: headline numbers in Light at the size of the Zune player's giant title or its next step down.
- VIS-02 Black background, white text, the Zune player's secondary-text grey. Lots of empty space; left-aligned, Metro margins from the Zune tokens.
- VIS-03 **Gradient titles:** the Zune player's giant title gradient (its VIS-15, `#F28A3A` → `#EE1E8C`) recoloured from tennis-ball yellow-green to deep green. Starting values *tunable*: start `#C9E23A`, end `#1F7A3A`. Both stops MUST pass 4.5:1 against black for the title text; a unit test checks it.
- VIS-04 **Tiles:** flat, solid-colour squares and rectangles, square corners, no shadows, no ripple, no Material components. Tile colour *tunable*, default one deep green `#2A7F3E` for every tile (Q4), white text and glyphs passing 4.5:1 (unit test). Press feedback is the Windows Phone tilt (copy the Zune player's tilt if it has one; else the launcher's `Tilt.kt` behaviour, reimplemented).
- VIS-05 **Lists** are Zune-style plain text rows: a primary line in the list size, a secondary line in grey; no cards, dividers or icons in rows.
- VIS-06 **Icons:** Fluent UI System Icons (Filled), MIT, the same set as the launcher's weather tile, monochrome white, one size per context, optically centred. Needed glyphs: clock/timer (log session), arrow-repeat or wrench (restrung), camera, chart, notepad (cues), library/book, heart-pulse (detected session), checkmark, dismiss. If the set has no tennis glyph, use none rather than drawing one; any custom glyph needs Chris's approval from a screenshot first. No illustrations, emoji or multi-colour art anywhere.
- VIS-07 Motion: the Zune player's pivot swipe, page turnstile/slide-in and tilt, at its tuned values.
- VIS-08 No accent colours other than VIS-03 and VIS-04. The phone's status bar stays visible.

## 4 Navigation and screens

- NAV-01 One hub with five pivots, swiped horizontally: **cues · strings · sessions · stats · library**. The app opens on **cues** (v0.3). Title (v0.3, Chris's option a): the Windows Phone pivot: a small all-caps `TENNIS` at the top, the pages' large lowercase headers below it, the current one filled with the VIS-03 gradient and the next one peeking in grey from the right. Pages below the hub use the same small title over their own large lowercase header. No clipped giant title anywhere.
- NAV-02 **strings** pivot (v0.3), top to bottom: the racquet switcher (RAC-04); tiles in mixed sizes (small, medium, wide) with real data, WP style: a big number over a small label: hours on strings, tension (`55/53` over `lb main/cross`), days strung, feel with its trend line; a wide setup tile (strings, gauges, hybrid, date strung; the package photo behind it once PH-4 exists); small glyph tiles for log session and restrung (and camera from PH-4). No tile without useful content. Below the tiles, this racquet's recent restrings as Zune text rows. Three tile layouts (grid, hero, mixed) are built; settings chooses one until Chris picks (Chris, 5 Nov). The original v0.2 list follows for reference:
  - a wide tile per racquet that has a string job (Q11, v0.2), most recently used racquet first: its hours on the current strings as a big number (e.g. `14.5`) with "hours on these strings" under it (with the racquet's name when there is more than one), and the string job's age ("restrung 23 days ago");
  - a wide tile: the current setup in two lines (`Mains: Solinco Hyper-G 16L @ 52 lb` / `Crosses: Luxilon Alu Power 125 @ 50 lb`), tapping opens the shop order card (STR-20);
  - four square tiles, two per row (*tunable* layout; PH-0 preview): **log session**, **restrung**, **camera**, **warmup** (opens the cues pivot);
  - if a detected session is waiting: a wide tile above all others, "Did you just play tennis?" with the window ("Today 5:10–6:35 PM"), tapping opens the prompt (DET-30).
- NAV-03 **sessions** pivot: text rows, newest first. Primary: date and duration ("Sat 2 Nov · 1 h 25 min"); secondary: feel rating and, for detected sessions, average/max heart rate and steps. Tap opens the session for editing; long-press offers delete (Zune-style context menu).
- NAV-04 **stats** pivot: section 9.
- NAV-05 **library** pivot: string jobs first ("history"), then strings ("strings"), as two text-row lists under small Zune headers. String job row: date, primary: string name(s) and tension, secondary: racquet, shop, price, hours played on it.
- NAV-06 Back always returns to the hub on the pivot it came from. The app opens to **strings**, except when started from the live tile with a proposal (TIL-11).
- NAV-07 Forms (restring, session, cue) are full pages in Metro form style: field label in small grey text over a plain underlined text field, a bottom app bar with save (check) and cancel (dismiss) glyph buttons, Windows Phone style.
- NAV-08 Settings page from the app bar's "…": export, import, Claude API key, detection thresholds (DET-11), Health Connect status, diagnostics (crash log, the DET-01 dump).

## 5 String jobs (restrings)

- STR-01 Fields: date; racquet; mains string; crosses string (same as mains by default, a "hybrid" switch shows a separate crosses string); for each string: brand, model, gauge, material; mains tension and crosses tension (lb default, kg option, Q7); shop; price (currency, Q7); optional notes; photos (PHO).
- STR-02 Material is a pick list: polyester, co-poly, multifilament, synthetic gut, natural gut, Kevlar/aramid, hybrid-other; plus free text.
- STR-03 **Restrung today** (the "restrung" tile): opens the restring form pre-filled with the last string job's racquet, strings, tensions, shop and price, and today's date. Saving unchanged is one tap. Changed fields are highlighted in the gradient start colour until saved.
- STR-04 Strings used in a job are added to the string library (STR-30) automatically; pick-lists for brand/model/gauge/material/shop/racquet fill from previous entries.
- STR-05 A session belongs to the string job that was current for its racquet on the session's date. Editing a job's date reassigns sessions accordingly.
- STR-20 **Shop order card:** a full-screen page, black, large type, for showing at the counter: racquet, then for mains and crosses: brand + model, gauge, tension, and the pre-stretch/notes line if any. Readable at arm's length (no text smaller than the Zune list size). Keeps the screen on while shown.
- STR-30 **String library:** each distinct string (brand, model, gauge, material), with its package photo if any, the jobs that used it, and its average feel rating. Editable; a string can be added by hand or from a photo.

## 5a Racquets (v0.3)

- RAC-01 Several racquets, each with a name (e.g. "Black Blade #1"), model and colour.
- RAC-02 Each racquet has its own string jobs: string or hybrid, mains and crosses tension, date strung, shop (STR-01).
- RAC-03 Hours on a racquet's current strings count only sessions logged with that racquet. A session with several racquets gives each an equal share of its length.
- RAC-04 The strings page switches racquets with one tap on its name in a row at the top; long-press a name to edit or delete the racquet; `+` adds one.
- RAC-05 Logging or confirming a session asks which racquets were used, defaulting to those of the last session; more than one can be chosen.

## 6 Sessions

- SES-01 **Log session** tile opens a minimal page: date (today), duration (picker with presets 60/90/120 min, *tunable*), optional feel rating, save. Three taps for the common case.
- SES-02 Feel rating: 1 to 5 (Q6), one tap on a row of five numbers; tap again to clear.
- SES-03 Hours are tracked per racquet (Q11, v0.2): a racquet's hours on its current strings = sum of the durations of confirmed sessions belonging to that racquet's current string job (STR-05). Shown to one decimal (*tunable*).
- SES-05 With more than one racquet, the session page has a racquet choice, defaulting to the racquet of the last session; a detected session (DET-30) asks the same way.
- SES-04 A session from detection (DET) also stores its source (exercise session / heart-rate window), start and end times, average and max heart rate, and steps.

## 7 Automatic session detection (Health Connect)

Chris's Fitbit Charge 6 syncs to the Google Health app, which writes to Health Connect. What it writes, and at what resolution, isn't known until DET-01 runs on his phone; DET-10 onward may change after it.

- DET-01 **Diagnostic (PH-0):** a settings page that, after Chris grants the read permissions, dumps one chosen day of Health Connect data: every record of HeartRate (with sample count and median spacing between samples), Steps (interval lengths), ExerciseSession (type, start, end, title) and RestingHeartRate, plus each record's data origin (writing app package). Shows a summary on screen and shares the full dump as a text file, so Chris can attach it in a session.
- DET-02 Permissions: READ_HEART_RATE, READ_STEPS, READ_EXERCISE, READ_RESTING_HEART_RATE, and READ_HEALTH_DATA_IN_BACKGROUND (for DET-20). The app MUST provide the permission-rationale/privacy activity Health Connect requires. If Health Connect or a permission is missing, the strings pivot shows nothing about detection and settings explains what to grant.
- DET-10 **Order:** (1) an ExerciseSession of type tennis (or, Q8, any racquet/other intense type) from any origin: use its start/end; (2) else a sustained heart-rate window: at least 30 min (*tunable*) where the rolling 5-minute (*tunable*) average heart rate stays above the threshold, allowing gaps of up to 5 min (*tunable*) below it; the window is clipped to the first and last minute above the threshold.
- DET-11 Threshold default: resting heart rate + 50% of heart-rate reserve (*tunable*), max heart rate = 220 − age (Chris's birth year in settings). Shown and editable in settings, with the last detection's numbers for comparison.
- DET-12 For the window: duration, average and max heart rate, total steps. These are attached to the session on Yes.
- DET-13 Windows that overlap a session already logged (by hand or confirmed) are not proposed. A rejected window is never proposed again.
- DET-20 A periodic WorkManager check every 60 min (*tunable*; Android's minimum is 15), looking back 48 h (*tunable*), because Fitbit sync can lag hours. Also runs when the app opens. No notification is ever posted (SCP-20).
- DET-30 **Proposal prompt:** a full page, "Did you just play tennis?", the day and window in large type, duration, average/max heart rate, steps, and two large tiles **yes** and **no**. Yes opens the session page pre-filled (feel rating optional) so one more tap saves; No rejects it. Several waiting proposals are shown one after another, oldest first.
- DET-31 A proposal older than 7 days (*tunable*) is dropped without logging.

## 8 Live tile on the WP launcher

Modelled on the interface the launcher already uses with the Zune player (its BACKBURNER 17: a read-only content provider with a fixed authority, `notifyChange` on update, an activity intent with a fixed action for taps, a `resolveContentProvider` support check). The launcher-side work is in `LAUNCHER-REQUESTS.md`, written to be handed to the launcher's session; until it ships, nothing in the launcher changes.

- TIL-01 **Tile provider:** authority `io.github.wotworth.tennis.tile`, read-only, answering only `io.github.wotworth.wplauncher` and `io.github.wotworth.wplauncher.preview` (calling-package check). One URI, `content://io.github.wotworth.tennis.tile/tile`, one row, columns:
  - `state` (text): `proposal`, `hours` or `empty`;
  - `big` (text): the big line, e.g. `14.5` (hours, for the most recently used racquet) or `Tennis?` (proposal);
  - `small` (text): the line under it, e.g. `hours on these strings` or `Today 5:10–6:35 PM`;
  - `proposal_id` (text, null unless `state` is `proposal`);
  - `updated` (integer, epoch ms).
- TIL-02 The app calls `notifyChange` on that URI whenever any column would change: a session saved, edited or deleted, a restring saved, a proposal created, answered or expired.
- TIL-10 **Tap intent:** activity intent, action `io.github.wotworth.tennis.action.OPEN_FROM_TILE`, package `io.github.wotworth.tennis`, optional text extra `proposal_id`.
- TIL-11 With a `proposal_id` that is still waiting, the app opens straight to its prompt (DET-30); otherwise to the strings pivot.
- TIL-12 `state` `empty` (no string job yet): `big` is empty and the launcher draws its normal tile.

## 9 Stats

- STA-01 Hours on the current string job (same number as NAV-02), sessions count, days since restring.
- STA-02 Feel over the life of each string job: a line of feel rating against cumulative hours, one line per job (current job highlighted in the gradient start colour, others grey). Flat, no gridlines beyond a baseline, Metro labels.
- STA-03 Comparison across jobs: a dot per job of mains tension against average feel; a text list under it (job, tension, average feel, hours lasted).
- STA-04 Per year: number of restrings, total spent, average hours per string job.
- STA-05 Charts drawn in Compose Canvas with the app's tokens; no chart library styling.

## 10 Swing cues

- CUE-01 A cue: a stroke heading (forehand, backhand, serve, volley, return, footwork, mental; plus free text) and a short text.
- CUE-02 The cues page lists cues grouped by heading as text rows; add, edit, delete, drag to reorder, and pin/unpin (pin is a glyph toggle at the row end, Metro style).
- CUE-10 **cues** pivot (Q5, v0.2) is the warmup view: the pinned cues first, in pinned order, in large Metro text (sized to fit up to 6 cues on one screen, *tunable*), heading in small grey over each cue; keeps the screen on while shown. Below them, the other cues in the list size; editing (CUE-02) opens from a cue's long-press and from the app bar.

## 11 String package photos

- PHO-01 **Camera** tile (and a camera button in the restring and string forms): takes a photo through Android's camera app (`ACTION_IMAGE_CAPTURE` into the app's storage via FileProvider; no CAMERA permission) or picks one from the gallery.
- PHO-02 The photo is always stored with the string entry (full resolution JPEG in app storage) as the record. Hybrids: a mains photo and a crosses photo.
- PHO-10 **Step 1, on device:** ML Kit text recognition (bundled Latin model, offline). Parse brand (from a list of known string brands, *tunable* file), model, gauge (`16L`, `17`, `1.25 mm`, `125` → gauge table) and material (keywords and the string-library history). Show the parsed fields pre-filled for confirmation, with the photo above them.
- PHO-20 **Step 2, Retry with Claude:** a "retry" button sends the photo (downscaled to at most 1568 px on the long side, JPEG) to the Claude Messages API with Chris's API key, asking for brand, model, gauge, material (inferred from the product name when not printed) as JSON with a fixed schema (structured output). Model `claude-sonnet-5-5` (*tunable*, Q9, v0.2). The result pre-fills the same confirmation fields.
- PHO-21 Offline (no validated network): the retry button shows "Needs an internet connection" and sends nothing. API errors show a plain message (bad key, rate limit, server error).
- PHO-22 The API key is entered in settings, stored encrypted with an Android Keystore key, never logged, never exported (DAT), never hard-coded. Settings shows only its last 4 characters and a remove button.
- PHO-23 Network rules: INTERNET permission used only for `api.anthropic.com`, HTTPS only, enforced in one network class and the network security config (no cleartext). CI fails if any other code uses the network.

## 12 Data

- DAT-01 Everything is stored in the app's private storage (Room database + photo files).
- DAT-02 **Export:** one zip (JSON of all records with a schema version, plus the photos) saved through Android's file picker. **Import:** from such a file, replacing all data after a confirmation.
- DAT-03 Android Auto Backup excluded (the export is the backup), so restores are explicit.
- DAT-04 Database migrations are tested from every released schema version (a phone update never loses data).

## 13 Non-functional

- NFR-01 No analytics, crash reporting services or ads. ML Kit's own usage logging, if any, is noted in `DECISIONS.md` (Q10).
- NFR-02 Crash log kept in app storage, shown and shared from settings (as the Zune player's NFR-20).
- NFR-03 All screens readable at the default font size and display size of Chris's S25; text never truncated in headline tiles (shrink to fit).
- NFR-05 Permission allowlist, checked in CI (section 0).
- NFR-04 Cold start to the strings pivot under 800 ms on the S25 (*tunable* target).

## 14 Delivery phases

Each phase ends in an installable build Chris accepts on his phone before the next starts. Each report goes in `docs/reports/`, with screenshots committed beside it.

1. **PH-0 Foundation and Health Connect diagnostic.** Repo, CI, signing, crash log, tokens, fonts, gradient title, the hub with its five pivots (the strings tiles as a static preview), and DET-01/DET-02.
   - Accept when: the build installs and updates over itself; Chris runs the diagnostic on a day he played and attaches the dump.
2. **PH-1 Logging.** Sections 4–6 and 12, the shop order card, string library, and the full look of section 3.
   - Accept when: Chris logs a restring and a session in the stated taps; export then import restores everything; Chris approves the look.
3. **PH-2 Detection.** Section 7, using what the PH-0 dump showed.
   - Accept when: over a week, every session Chris played was proposed (allowing sync delay), and false positives were few enough to tolerate.
4. **PH-3 Live tile.** Section 8, plus a test app or unit tests that read the provider as the launcher would. Lands on the phone fully once the launcher side (LAUNCHER-REQUESTS.md) ships.
   - Accept when: the tile shows hours, switches to the proposal after a detection, and a tap opens the prompt.
5. **PH-4 Photos.** Section 11.
   - Accept when: a photo of each of Chris's current string packages fills brand, model, gauge and material either on device or with retry.
6. **PH-5 Stats and cues.** Sections 9 and 10.
   - Accept when: Chris approves the charts and uses the warmup page before a session.

## 15 Reference material

- REF-01 The Zune player repo (look, fonts, components). REF-02 The launcher's weather tile at v0.9.150 as the bar for icon and tile polish. REF-03 Optional: photos of Chris's current string packages in `/reference/packages/` for PH-4 tests.

## 16 Decisions and open questions

**Decisions made.**

| Decision | Reason |
| --- | --- |
| Separate repo and app; styling copied from the Zune player, not shared as a library | Each app ships on its own; a shared module would tie their builds together |
| The launcher reads a content provider, as it does for the Zune player | Proven pattern in both apps; the launcher already refreshes on `notifyChange` |
| No notifications at all, even for detections | Brief: no reminders; the tile and the strings pivot carry proposals |
| Android's camera app, not an in-app viewfinder | No CAMERA permission, best photo quality, far less code |
| Fluent UI System Icons | Same set as the launcher's approved weather tile |

**Questions** (answered by Chris on 5 November 2026; the last column is what was decided).

| # | Question | Decided |
| --- | --- | --- |
| Q1 | Repo name | `Wotworth/tennis` (created by Chris) |
| Q2 | App name on the phone and the launcher tile | `tennis` (lowercase, Zune style) |
| Q3 | Gradient start/end colours | `#C9E23A` → `#1F7A3A`, tuned from screenshots |
| Q4 | Tiles: all one green, or mixed greens and a yellow-green hours tile | All one deep green |
| Q5 | Cues: a fifth pivot, or a tile on strings | Fifth pivot: the warmup view, top cues large (Chris) |
| Q6 | Feel scale | 1–5 |
| Q7 | Units | lb and US dollars |
| Q8 | Which exercise types count as tennis in DET-10 | Tennis only; others go to the heart-rate rule |
| Q9 | Claude model for retry | `claude-sonnet-5-5` (Chris) |
| Q10 | Accept ML Kit (Google library, may send anonymous usage stats) | Yes |
| Q11 | One racquet or several with their own strings | Several; hours tracked per racquet (Chris) |
