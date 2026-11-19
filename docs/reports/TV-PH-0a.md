# TV-PH-0, part 1: where to mount the cameras (provisional)

Spec: [VISION-REQUIREMENTS.md](../VISION-REQUIREMENTS.md) TV-CAL-03 and TV-CAL-04, with Chris's answers of 15 Nov (section A). Everything here comes from GoPro's published lens figures, not from a camera. It is **provisional until a lens is calibrated** (TV-CAL-01).

## The lens figures

GoPro's support article for the MISSION 1 and MISSION 1 PRO gives three angles for each digital lens, with HyperSmooth off. The **112–156° on the box are diagonal angles.** Horizontally the lenses cover 100° (Linear) and 128° (Wide and SuperView).

| Lens | Frame | Across | Up and down | Diagonal |
|---|---|---|---|---|
| Wide | 16:9 | 128° | 75° | 144° |
| Wide | 4:3 Open Gate | 128° | 99° | 156° |
| Linear | 16:9 | 100° | 67° | 107° |
| Linear | 4:3 | 100° | 83° | 112° |
| SuperView | 16:9 | 128° | 99° | 156° |

- **SuperView** is the 4:3 Wide picture stretched sideways to fill 16:9. The spec rules it out.
- **Switching Wide from 16:9 to 4:3** adds height, not width.
- **Where the figures came from.** The session's network can't reach GoPro's site, so the figures come from search results quoting the article. They hang together:
  - Linear matches a distortion-free lens exactly.
  - One lens model fits all six Wide angles to within 0.6°.

## The lookup table

How to read the table:
- Both cameras go on the same side, one at each end, mirror images of each other.
- **Fence distance** is measured from the doubles sideline to the side fence.
- **Error** is the bounce-position error at the worse far corner, for one frame from each camera, if each camera misreads the ball by 1 pixel. The flight-path fit uses many frames, so it should do better; calibration and timing errors come on top. The field tests (AC-08) give the real number.

| Side fence from doubles sideline | Mount | Spot along the fence (both cameras, same side) | Height | Frame | Aim | Far-corner bounce error | Ball at far corner | Worst spot in the air | Why not the fence |
|---|---|---|---|---|---|---|---|---|---|
| 2 m | fence | 1.5 m behind each baseline | 3.0 m | 4:3 | turned 25° toward the net, tilted 15° down | 1.8 cm | 4.1 px | 3.1 cm | - |
| 3 m | fence | 1.0 m behind each baseline | 3.5 m | 16:9 | turned 25° toward the net, tilted 22° down | 1.9 cm | 4.1 px | 2.3 cm | - |
| 4 m | fence | level with each baseline | 3.5 m | 16:9 | turned 22° toward the net, tilted 12° down | 2.0 cm | 4.0 px | 2.5 cm | - |
| 5 m | fence | 0.5 m in from each baseline, toward the net | 3.0 m | 16:9 | turned 22° toward the net, tilted 4° down | 2.2 cm | 4.0 px | 2.7 cm | - |
| 6 m | fence | 2.0 m in from each baseline, toward the net | 3.5 m | 16:9 | turned 18° toward the net, tilted 0° down | 2.5 cm | 4.1 px | 3.1 cm | - |
| 7 m | fence | 2.5 m in from each baseline, toward the net | 3.5 m | 16:9 | turned 18° toward the net, tilted 1° up | 2.8 cm | 4.1 px | 3.4 cm | - |
| 8 m | light stand, 5.0 m from the sideline | 0.5 m in from each baseline, toward the net | 3.0 m | 16:9 | turned 22° toward the net, tilted 4° down | 2.2 cm | 4.0 px | 2.7 cm | far-corner error on the fence is 3.2 cm, over 3 cm |
| 9 m | light stand, 5.0 m from the sideline | 0.5 m in from each baseline, toward the net | 3.0 m | 16:9 | turned 22° toward the net, tilted 4° down | 2.2 cm | 4.0 px | 2.7 cm | far-corner error on the fence is 3.8 cm, over 3 cm |
| 10 m | light stand, 5.0 m from the sideline | 0.5 m in from each baseline, toward the net | 3.0 m | 16:9 | turned 22° toward the net, tilted 4° down | 2.2 cm | 4.0 px | 2.7 cm | far-corner error on the fence is 4.6 cm, over 3 cm |

**How the check decides.** Results are in `vision/config/placement.json`, which also holds every threshold.
1. **The court must fit.** Both cameras must see the whole court, 3 m behind each baseline and up to 4 m high, with 2° to spare for aiming by hand.
2. **The ball must be big enough.** It must be at least 4 pixels wide at the far corners.
3. **The error must be small enough.** It must be 5 cm or less.
4. **Light stand rule.** A light stand is recommended when the fence fails, or when its error is over 3 cm and a stand does better. Stands go 3–5 m out (the spec's range), as far out as works: farther is safer for players chasing wide balls.

![error and ball size by fence distance](TV-PH-0a/placement_error.png)

![layout for a fence 4 m out](TV-PH-0a/placement_layout.png)

## What it shows

1. **Every fence from 2 to 7 m works.** The cameras move toward the net as the fence gets farther away:
   - At 2–3 m they go behind the baselines.
   - At 4 m they go level with them.
   - At 7 m they go 2.5 m in front.
2. **A fence 2 m out needs 4:3 Open Gate.** In 16:9 the near part of the court doesn't fit top to bottom.
3. **From 8 m out, use light stands 5 m from the sideline.** The fence still passes, but its error grows to 3.2–4.6 cm, against 2.2 cm on a stand.
4. **The ball's size is the real limit, not accuracy.** At 4K the ball is about 4 pixels wide at the far corners wherever the cameras go, right at the edge of what a detector can find (the spec says 4–7 px).
   - 8K60 would make it about 8 pixels. 4K240 doesn't change the size.
   - This feeds the capture-mode choice at the end of TV-PH-2. Keep 8K60 in the TV-PH-0 trials.
5. **Height barely matters for accuracy.** Anything from 2.5 to 3.5 m changes the error by hundredths of a centimetre. The table prefers the higher mount, which sees over players (this check doesn't model players).
6. **The spec's geometry checks out.** The tests confirm it:
   - from the service-line spots a camera needs 132° across;
   - from the baseline spots it needs 115–120°;
   - the sight lines cross at about 100° at the net.
   - The Wide lens's 128° covers the baseline spots with about 5° to spare on each side.

## Layout 2: back-fence corners, same side (added 16 Nov)

Both cameras in the back-fence corners at the two ends, on the same side of the court. Back fences sit 4–7 m behind the baseline (6.4 m is the usual recommendation) and the corner is 2–5 m outside the doubles sideline. Every combination was checked at 2.5, 3.0 and 3.5 m high, in all four lens modes. The full table, one row per spot and mode, is in [TV-PH-0a/placement_layout2.md](TV-PH-0a/placement_layout2.md); these are typical corners:

| Corner (behind baseline, outside sideline) | Lens, frame | Whole court in view | Weakest crossing on court | At the net over the cameras' singles sideline | Weakest crossing in the air | Farthest corner | Ball there | Far-corner bounce error |
|---|---|---|---|---|---|---|---|---|
| 5.5 m, 3.0 m | Wide 16:9 | yes | 25° | 30°, 2.9 cm | 20° | 32.5 m | 3.4 px | 1.9 cm |
| 6.4 m, 3.66 m | Wide 16:9 | yes | 29° | 33°, 2.8 cm | 23° | 33.7 m | 3.3 px | 2.0 cm |
| 6.4 m, 3.66 m | Wide 4:3 | yes | 31° | 34°, 2.8 cm | 23° | 33.7 m | 3.3 px | 2.0 cm |
| 6.4 m, 3.66 m | Linear 16:9 | yes | 31° | 34°, 2.1 cm | 23° | 33.7 m | 3.5 px | 1.8 cm |
| 4.0 m, 2.0 m (tight) | Wide 16:9 | 99.7% | 25° | 28°, 2.7 cm | 16° | 30.8 m | 3.8 px | 1.8 cm |
| 7.0 m, 5.0 m (roomy) | Wide 16:9 | yes | 33° | 38°, 2.5 cm | 30° | 34.8 m | 3.2 px | 2.1 cm |

The "In the air" and "error" columns use the same method as layout 1: 1 px of error in one frame from each camera.

What it shows:
1. **Your crossing-angle estimate holds.** The weakest spot on the court is at the net, on the cameras' side, over the doubles sideline. It ranges from 21° to 42° depending on the corner, and is about 25–30° at typical corners. In the air above that spot it drops to 12–36° (about 20–23° typically), under the provisional 20° threshold at the tighter corners. So the ntfy message will name that zone for some courts.
2. **For singles that zone is mostly the alley.** Over the singles sideline at the net, the angle is 23–47°, and the position error there is 1.5–3.8 cm for 1 px. That is no worse than the far corners.
3. **The ball is smaller than you estimated.** At the far corner it is 3.1–3.8 px wide with Wide, 3.2–4.1 px with Linear, at 31–35 m. You estimated 3.5–4.5 px. Every corner fails the 4 px rule at 4K, worse than layout 1 (about 4 px). This makes 8K60 more important for layout 2 courts in the TV-PH-0 trials.
4. **Accuracy is good.** The far-corner bounce error is 1.5–2.1 cm, against 1.8–2.8 cm for layout 1 on a fence, because the far corners are seen from two very different directions.
5. **Linear fits from the corners.** From behind the baseline, Linear's 100° covers the whole court, and its ball is about 0.2 px bigger. The spec says Wide; worth one Linear trial on a layout 2 court.
6. **Height barely matters**, as in layout 1.

These figures are provisional, like the rest of this report: they use the published lens figures. They are listed in VISION-RETUNE.md.

## Not modelled

- the sun (pick the side that keeps it behind the cameras);
- fence posts, light poles and neighbouring courts in the view;
- players blocking the ball;
- the real size of the 4:3 frame (assumed 3840 × 2880).

## What CI proved

Pending: the Vision tests workflow is running. Until it finishes, the table above is from GNU Octave in the session, where all five test files pass.

The PC setup script (`vision/setup/Setup-ClosetPC.ps1`) is written but untested. There is no Windows here; it runs when the PC exists.

## Next in TV-PH-0 (needs the hardware)

1. Buy the kit. Check each court's fence distance against the table before choosing clamps or light stands.
2. Record the lens calibration: 60 s of the checkerboard per camera, in each mode you'll use. Then I re-run this check with the measured lens.
3. Record the trial sessions: 4K120 16:9, 4K120 4:3 Open Gate, 4K240 and 8K60, each on external power, to test heat.

## Linear lens (19 Nov 2026)

Chris plans to record in Linear, and asked for the placement check to confirm that Linear still covers the court from the fence before it is recommended. The same check, with the lens set to Linear (100° across; `tv.placement.lookupTable` with `recommendLens` = Linear, run in the session; the table above is Wide):

| Side fence from doubles sideline | Mount | Spot along the fence (both cameras, same side) | Height | Frame | Aim | Far-corner bounce error | Ball at far corner | Worst spot in the air |
|---|---|---|---|---|---|---|---|---|
| 2 m | fence | 3.5 m behind each baseline | 3.5 m | 4:3 | turned 42° toward the net, tilted 24° down | 1.5 cm | 4.2 px | 2.8 cm |
| 3 m | fence | 3.5 m behind each baseline | 3.5 m | 16:9 | turned 38° toward the net, tilted 21° down | 1.5 cm | 4.1 px | 1.9 cm |
| 4 m | fence | 2.5 m behind each baseline | 3.5 m | 16:9 | turned 37° toward the net, tilted 20° down | 1.6 cm | 4.1 px | 1.9 cm |
| 5 m | fence | 1.5 m behind each baseline | 2.5 m | 16:9 | turned 31° toward the net, tilted 4° down | 1.7 cm | 4.0 px | 2.0 cm |
| 6 m | fence | 1.0 m behind each baseline | 2.5 m | 16:9 | turned 30° toward the net, level | 1.9 cm | 4.0 px | 2.1 cm |
| 7 m | light stand, 5.0 m from the sideline | 1.5 m behind each baseline | 2.5 m | 16:9 | turned 31° toward the net, tilted 4° down | 1.7 cm | 4.0 px | 2.0 cm |
| 8 m | fence | 0.5 m in from each baseline, toward the net | 3.5 m | 16:9 | turned 25° toward the net, level | 2.2 cm | 4.0 px | 2.4 cm |
| 9 m | fence | 1.5 m in from each baseline, toward the net | 3.5 m | 16:9 | turned 22° toward the net, tilted 3° down | 2.4 cm | 4.0 px | 2.7 cm |
| 10 m | fence | 2.5 m in from each baseline, toward the net | 3.5 m | 16:9 | turned 19° toward the net, level | 2.8 cm | 4.1 px | 3.0 cm |

What it shows:

1. **Linear does cover the court from every fence distance, but not from the same spots as Wide.** The cameras go further back along the fence: 2.5 m behind each baseline for a fence 4 m out, where Wide sits level with the baseline; 3.5 m behind for a fence 2 or 3 m out. The side fence has to run that far behind the baseline (it normally runs to the back fence, 6.4 m behind).
2. **The cameras turn further toward the net** (about 30° to 40° instead of 20° to 25°), so each looks more along the court.
3. **Accuracy is a little better than Wide** (1.5 to 1.9 cm against 1.8 to 2.5 cm for fences 2 to 6 m out), and the ball is the same size at the far corner, about 4 px: the narrower lens gives more pixels per degree but the camera sits further away.
4. At 7 m the fence spot fails by a hair on ball size (under 4 px at the far corners) and a light stand is given; 8 m passes again. The ball-size limit is being met to the decimal, so treat 7 to 8 m as borderline in either lens.

Still provisional: GoPro's published angles, not a measured lens (TV-CAL-01).
