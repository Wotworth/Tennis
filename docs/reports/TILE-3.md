# Live tile: cues only

Release: _added once CI publishes it_ (tag `tile-3`). Spec v0.8 (TIL-05).

From Chris's screenshot (7 Nov): the tile showed "0 sessions this mo…", the back face (last session, or this month's count when none is logged). The back face is gone: the tile flips through cues only, and "Tennis?" takes over when a session is found. Tennis app only; launcher v0.9.173 needs no update.

Only cues that fit in full at the tile's size are shown. If none fits, the tile shows the racket icon; long cues often fit only on a wide tile.

Tests: 94 pass.

## Test steps for Chris

1. Install this release (keep launcher v0.9.173).
2. Press Home: the tennis tile no longer shows "sessions this month". It shows a cue that fits, flipping to the next one, or the racket if none fits.
3. If you see only the racket on the medium tile, make the tile wide, or add a short cue (a few words) and press Home.
