# Launcher requests: live tile for the tennis app

For the wp-launcher's Claude Code session. Written 4 November 2026 against wp-launcher v0.9.150 (fix-7).

**Status (6 Nov): on launcher main** (merged on top of v0.9.160), with the faces flip below. Earlier: **built (5 Nov).** The tennis app's session implemented all of this in Wotworth/wp-launcher on branch `ccr-eb362149-pgs534` (one commit, `9c08e8e`, on top of `ccr-fa86e307-85zu7m` at `e3b6d8e`), with unit tests (`TennisTileTest`) and a CHANGELOG entry, and released it with checkpoint `tennis-tile`. **For the launcher's next session:** fast-forward or merge `ccr-eb362149-pgs534` into your branch before your next release, or the tile goes away again.

## What Chris wants

Chris's new tennis app (package `io.github.wotworth.tennis`, label "tennis") logs his tennis sessions and string jobs. When it's pinned to Start, its tile becomes a live tile:

- Usually it shows the hours played on the current strings of his most recently used racquet, e.g. **14.5** with "hours on these strings" under it.
- When the app has detected a possible tennis session from his Fitbit data, the tile shows **Tennis?** with the time window under it, e.g. "Today 5:10–6:35 PM". Tapping it opens the tennis app straight to a Yes/No prompt for that session.

## Interface (the tennis app provides it; exact names)

The same shape as the Zune player's Pin Music interface (BACKBURNER 17). Treat every value as opaque text.

- **Provider:** authority `io.github.wotworth.tennis.tile`, read-only. It answers only `io.github.wotworth.wplauncher` and `io.github.wotworth.wplauncher.preview`.
- `content://io.github.wotworth.tennis.tile/tile`: exactly one row. Columns:
  - `state` (text): `hours`, `proposal` or `empty`;
  - `big` (text): the large line, e.g. `14.5` or `Tennis?`;
  - `small` (text): the line under it, e.g. `hours on these strings` or `Today 5:10–6:35 PM`;
  - `proposal_id` (text): set only when `state` is `proposal`, else null;
  - `updated` (integer): epoch milliseconds of the last change.
- The provider calls `notifyChange` on that URI whenever any column changes.
- **Tap intent:** an activity intent with action `io.github.wotworth.tennis.action.OPEN_FROM_TILE` and package `io.github.wotworth.tennis`. When the row has a `proposal_id`, put it in the text extra `proposal_id`. The tennis app handles a stale or missing id by opening its home screen.
- **Support check:** `PackageManager.resolveContentProvider("io.github.wotworth.tennis.tile", 0)`. Add `<queries><provider android:authorities="io.github.wotworth.tennis.tile" /></queries>` to the manifest (the launcher has no QUERY_ALL_PACKAGES, as with the Zune provider). While the check fails, the tile is a normal app tile.

## Launcher behaviour requested

1. **Which tile:** any Start tile for the app `io.github.wotworth.tennis` (its normal app tile; no new "add" menu item).
2. **Look:** reuse the Battery tile's text layout (`TileInfo`): `big` in Light at the Battery tile's size (Header 46 epx; 34 epx on small tiles), `small` in Caption 12 epx under it, shrunk to fit the width; white text on the tile's normal colour. Small tiles show `big` only. The app label stays at the bottom-left as usual.
3. **Proposal state:** same layout. If the launcher's live-tile flip (BACKBURNER 18a) is available, the tile COULD flip between the proposal and the app's glyph on the flip timer, to draw the eye; otherwise static.
4. **`empty`, or a row that can't be read:** draw the normal tile.
5. **Tap:** when `state` is `proposal`, start the tap intent with `proposal_id`; otherwise also start the tap intent (no extra), falling back to the app's launch intent if it doesn't resolve.
6. **Refresh:** register a `ContentObserver` on the URI (as for the Zune provider), read the row on launcher start and when Start comes on screen. Never poll. Reads happen off the main thread.
7. **Setting:** Settings → tiles → Live tiles: a "tennis" switch, on by default, travelling with export/import like the other live-tile switches.
8. **Tests:** a unit test of the row-to-tile mapping (each state, missing columns, null `proposal_id`), and, if the CI helper app (or `fakezune`) pattern allows, a fake provider with the same authority for the emulator test.

## Not needed from the launcher

No notifications, no background work, no network, no Health Connect access. The tennis app does all detection and keeps the row up to date.

## Added 6 Nov (tennis v0.4): flip through racquets

Built on launcher main, additively.

- `content://io.github.wotworth.tennis.tile/faces`: one row per face, the same columns as `/tile`. With the tennis app set to "each racquet in turn", one face per active racquet (`big` = hours, `small` = "hours · racquet name"); otherwise one face. A waiting proposal is always the only face.
- The launcher flips the tennis tile through its faces with the playlist tiles' flip and timer (18a), at most 12; one face means no flipping. A tennis app without `/faces` keeps working as before.

## Added 6 Nov (tennis v0.6): text fits the tile

Built on launcher main, additively: the tennis tile's line under the number is cut with "…" to the width of the number (88% of the tile). Only the tennis tile. The tennis app now sends shorter text (`14.5` over `hours on strings`; with several racquets `14.5 h` over the racquet's name), and `empty` when Chris turns the live tile off.

## Added 6 Nov (tennis v0.7): the tile flips through cues

Built on launcher main, additively (see the launcher CHANGELOG).

- `/tile` `state`: `proposal` (a found session, shown as before), `cues` (the live tile is on) or `off` (the plain icon). Older launchers draw `cues` and `off` as the plain tile.
- `/cues`: one row per cue, `text` and `heading`, pinned cues first.
- `/back`: one row, `big` and `small` (the last session's day and length, or "0" over "sessions this month").
- The launcher fits each cue to the tile it is drawn on: whole words, 15 epx or at least 12 epx, inside the 8 epx label inset and above the label; cues that don't fit are skipped; none fits: the icon. Faces alternate cue, back, cue, back on the playlist flip timer; a small tile doesn't flip.

## Added 8 Nov (tennis v0.9): the stroke above each cue

Built on launcher main, additively. `/cues` rows now also carry `colour` (an ARGB number, the stroke's tile colour). The launcher draws the stroke (`heading`, lowercase) above the cue in that colour, semibold 11 epx, and reserves its line when fitting the cue.
