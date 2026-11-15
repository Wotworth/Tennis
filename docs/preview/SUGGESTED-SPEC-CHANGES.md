# Suggested spec changes (not made)

Things the build and the preview turned up. The spec is unchanged; each needs Chris's yes or no.

1. **Readout time (TV-SYNC-03).** Measure each camera mode's rolling-shutter readout once (TV-PH-0 trials) and treat it as known, instead of estimating it in every session. On synthetic footage the per-session estimate traded off against the clock offset (2.3 ms error); with the readout known, timing came within 0.15 ms.
2. **Usable crossing angle (TV-CAL-04, new).** Name a number. The build uses 20°, below which an ntfy alert names the weak zone. Both layouts cleared it on paper: about 41° near the baselines, 25° in the back-fence corners.
3. **Shot types before TV-PH-5.** The preview already shows forehand / backhand / serve, because trends and filters read better that way. Either pull a simple forehand/backhand rule (which side of the player the ball passes) into TV-PH-2, or keep "groundstroke" until TV-PH-5.
4. **Court map colours (TV-APP-03 against VIS rules).** The spec asks for bounces coloured by speed or spin. CLAUDE.md allows only the green gradient and tile green, so both scales run along the title gradient. A second scale colour would make spin and speed easier to tell apart; it needs an exception like the cues page has.
5. **TV-APP-07 tile state 3.** "New-session stats until the session is opened" brings back a stats line on the tile, which Chris removed for logged sessions on 7 Nov. Suggest: the vision-stats state lasts until opened, or 24 h, whichever comes first.
6. **Indoor flag timing.** Allow the indoor flag to be set after the session too (from the session page), not only by picking an indoor court beforehand.
7. **AC-10 on CI.** Keep AC-10 as is for field validation. CI's synthetic footage is a quarter of 4K resolution, so its test checks the median spin effect within 10 cm (every shot within 40 cm).
8. **TV-HC-02 zones.** Zones are shares of 220 − age. Suggest heart-rate reserve zones instead, matching the detection threshold (resting HR + share of reserve) the app already uses.
