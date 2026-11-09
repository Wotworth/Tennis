# Live tile: the stroke above each cue

Releases: tennis [v0.6.15](https://github.com/Wotworth/tennis/releases/tag/v0.6.15) (tag `tile-4`); launcher [v0.9.181](https://github.com/Wotworth/wp-launcher/releases/tag/v0.9.181) (from launcher main, includes v0.9.179). Spec v0.9 (TIL-06).

From Chris's screenshot (8 Nov): "Don't forget about the follow through" didn't say which stroke. Now each cue on the tile has its stroke above it in small letters ("forehand"), in the stroke's colour.

- **Size:** 11 points, semibold; the cue stays 15 (or 12 at the smallest). The stroke line's room comes out of the cue's, so a cue shows only if both fit.
- **Colour:** the app's stroke colours are made to read on black; on the tile's green several (cyan, orange, pink) were hard to read (under 2:1). The tile uses the same colours, lightened just enough to read at 3:1: forehand light blue, backhand light orange, serve light pink, return light teal, volley light amber, footwork light violet, gameplay light lime, mental light grey-blue.
- Launcher main also took the launcher session's latest fixes (v0.9.175 to v0.9.179) first, so this launcher release keeps them.

Tests: tennis 95 pass; launcher 225 pass (222 before, unchanged; 3 new).

## Test steps for Chris

1. Install both releases.
2. On Start, the tennis tile shows e.g. "forehand" in light blue above "Don't forget about the follow through".
3. Check the stroke name is readable at arm's length. If you'd prefer the exact app colours or white letters, tell me.
