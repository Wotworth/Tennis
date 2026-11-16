# Design v2: choices you can see and change (variations, 16 Nov)

Real screenshot tests (`DesignV2Screenshots`, 1080 × 2340) on the synthetic sample session, after "which one is you?" was answered. Nothing is applied to the app yet: pick one per screen, or mix (for example, court B with shot A and trends A).

**Opponent colour: cobalt blue `#4F7DFF`.** You stay green. Blue stays apart from green and the optic-yellow ball even for the commonest colour blindness (red–green). It is darker than, and 25° of hue away from, the cyan forehand colour on the cues page. Magenta was ruled out: it is your cap colour.

| Image | What it shows, and the design choice |
|---|---|
| [0-current-03a-court-map-forehands-speed](0-current-03a-court-map-forehands-speed.png) | Current court map, for comparison. |
| [0-current-04-shot-card](0-current-04-shot-card.png) | Current shot card. |
| [0-current-08-trends](0-current-08-trends.png) | Current trends. |
| [court-A-strips-everyone-speed](court-A-strips-everyone-speed.png) | **Court A.** Three segment strips, one line each, scrolling sideways (selected: tile green; others: dark grey). Each player has their own colour, shaded dark to light by speed, with one legend bar per player. Everyone selected. |
| [court-B-filterbar-everyone-forehands-speed](court-B-filterbar-everyone-forehands-speed.png) | **Court B.** One filter bar ("forehands · speed · everyone", filter icon, chevron) instead of the strips, so the map is about a third bigger. Same player shades and legends. |
| [court-B2-filterbar-panel-open](court-B2-filterbar-panel-open.png) | Court B with the bar tapped: the full-width, square flyout with every option as strips, the flat toggle for opponent's stats, and done / reset. The choices carry across the court, shots and rallies pivots. |
| [court-B3-filterbar-everyone-spin](court-B3-filterbar-everyone-spin.png) | Court B coloured by spin effect: the same shades, scaled 0–12 ft shorter. |
| [court-C-dot-size-everyone-speed](court-C-dot-size-everyone-speed.png) | **Court C.** The filter bar; each player's colour stays solid, and speed (or spin) sets the dot size, with a size legend. Who hit it is clearest; speed is harder to read where dots overlap. |
| [shot-A-two-column-grid](shot-A-two-column-grid.png) | **Shot A.** A swatch in the hitter's colour, the side view in that colour, then the figures in a two-column grid (number large, label small). App bar icons with labels: previous, next, looks wrong. |
| [shot-A2-two-column-grid-opponent-shot](shot-A2-two-column-grid-opponent-shot.png) | Shot A for an opponent's shot: blue swatch and path. |
| [shot-B-headline-and-groups](shot-B-headline-and-groups.png) | **Shot B.** Speed as the headline, with the hitter, type and call beside it; a shorter side view; the figures in two-column groups (flight, bounce, spin). |
| [trends-A-selectors](trends-A-selectors.png) | **Trends A.** The line becomes selectors (shot type, player, racquet), each with a chevron and an underline; it scrolls sideways when long. |
| [trends-A2-selectors-panel-open](trends-A2-selectors-panel-open.png) | Trends A with a selector tapped: the same flyout as the court map (shot type, player, racquet, measures). |
| [trends-B-filterbar-and-strip](trends-B-filterbar-and-strip.png) | **Trends B.** The same filter bar as court B, plus a strip for the shot type, which changes most often. |

**My recommendation:**
- Court B: the most room for the map, and one way of choosing across all data pages.
- Shot A: it fits most of a shot on one screen and keeps every figure.
- Trends A: it reads as a sentence you can change.

Everything stays black, square and flat, with Segoe-style type and Fluent Filled icons (new: filter, chevron, flag). No ripples, shadows or Material parts.
