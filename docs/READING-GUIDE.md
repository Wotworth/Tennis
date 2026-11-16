# Reading guide: the physics core, equation by equation

For Chris, as the MATLAB engineer reviewing it. Each section gives the equation, then the file and function that implements it, then what to look at. Paths are under `vision/`. Section numbers refer to `docs/VISION-REQUIREMENTS.md`. The last section lists every place where the code assumes something the spec doesn't state.

Conventions throughout (TV-ARCH-10 to 12):
- SI units inside the code;
- court frame: origin at the net centre on the ground, $y$ away from the cameras' side, $z$ up, $x = y \times z$;
- times in seconds of camera 1's clock ("session time").

Constants are in `+tv/+court/constants.m`:
- $g = 9.81$ m/s², ball mass 57.7 g, diameter 6.70 cm, so radius $r = 3.35$ cm;
- net 0.914 m at the centre and 1.07 m at the posts.

## 1. Equation of motion (TV-PHY-01, section 5)

$$
m\,\dot{\mathbf v} = m\,\mathbf g - \tfrac12 \rho A C_D \lvert\mathbf u\rvert\,\mathbf u + \tfrac12 \rho A C_L \lvert\mathbf u\rvert^{2}\,(\hat{\boldsymbol\omega}\times\hat{\mathbf u}), \qquad \mathbf u = \mathbf v - \mathbf w
$$

**Code:** `+tv/+physics/acceleration.m`. It divides by $m$ and folds the constants into $k = \tfrac{\rho A}{2m}$:

```matlab
u     = v - prm.wind;                       % velocity through the air
speed = norm(u);
k     = 0.5 * prm.rho * prm.area / prm.mass;
a     = [0 0 -prm.g] - k * prm.CD * speed * u;                  % gravity + drag
push  = cross(prm.spinAxis, u / speed);                         % omega-hat x u-hat
a     = a + k * prm.CL * speed^2 * push;                        % Magnus
```

**Check:**
- The Magnus term uses $\lvert\mathbf u\rvert^2$ and the cross product of two unit vectors. Its size is $k C_L \lvert\mathbf u\rvert^2 \sin\theta$, with $\theta$ the angle between the spin axis and the flight. It is largest when the axis is square to the flight.
- `spinAxis = [0 1 0]` for a ball flying along $+x$ is topspin (push down). The comment in `+tv/+physics/defaultParams.m` explains the right-hand rule.

## 2. The integrator: fixed-step RK4 (TV-PHY-01)

$$
\mathbf k_1 = \mathbf a(\mathbf v_n),\;
\mathbf k_2 = \mathbf a(\mathbf v_n + \tfrac{h}{2}\mathbf k_1),\;
\mathbf k_3 = \mathbf a(\mathbf v_n + \tfrac{h}{2}\mathbf k_2),\;
\mathbf k_4 = \mathbf a(\mathbf v_n + h\mathbf k_3)
$$
$$
\mathbf v_{n+1} = \mathbf v_n + \tfrac{h}{6}(\mathbf k_1 + 2\mathbf k_2 + 2\mathbf k_3 + \mathbf k_4), \qquad
\mathbf p_{n+1} = \mathbf p_n + \tfrac{h}{6}(\mathbf v_n + 2\mathbf v^{(2)} + 2\mathbf v^{(3)} + \mathbf v^{(4)})
$$

**Code:** `+tv/+physics/simulate.m`, with $h$ = `dt` = 1 ms. The force model is inlined (function `acc`) for speed. It is the same as `acceleration.m`, with the cross product written out.

**Check:**
- The position stages use the velocity stages (`k2p = v + dt/2*k1v`): correct for $\dot{\mathbf p} = \mathbf v$, because the force does not depend on position.
- `stopZ` stops at the first step below the ground height. `+tv/+physics/groundHit.m` then interpolates the touch linearly between the last two samples.
- `tests/physicsTest.m` checks RK4 against `ode45` to better than a millimetre.

## 3. One flight's fit to both cameras (TV-REC-01, TV-PHY-02, TV-SYNC-05)

Parameters of one flight:

$$
\mathbf x = [\,\mathbf p_0\;(3),\; \mathbf v_0\;(3),\; a_1,\; a_2,\; C_D\,], \qquad C_L\,\hat{\boldsymbol\omega} = a_1\,\mathbf e_1 + a_2\,\mathbf e_2
$$

Here $\mathbf e_1$ is horizontal and square to the flight (topspin $+$ / slice $-$), and $\mathbf e_2$ is square to both (sidespin).

The fit minimises, over all detections $i$ of both cameras, each at its own time $t_i$:

$$
\sum_i w_i \left\lVert \pi_{c(i)}\!\big(\mathbf p(t_i;\mathbf x)\big) - \mathbf q_i \right\rVert^2 + \left(\frac{C_D - \bar C_D}{0.024}\right)^2 + \left(\frac{a_1}{\sigma_L}\right)^2 + \left(\frac{a_2}{\sigma_L}\right)^2
$$

- $\pi_c$ is camera $c$'s projection with its lens (`+tv/+camera/project.m`).
- $\mathbf q_i$ is the detected pixel.
- $w_i$ are Huber weights at 2 px (three passes); after that, detections more than 6 px off are dropped if they are at most 10% of the flight.

**Code:**
- `+tv/+recon/segmentModel.m`: $\mathbf p(t;\mathbf x)$. It builds the spin axis from $a_1, a_2$ (`+tv/+recon/spinBasis.m`), runs `simulate` from $t_0$, and interpolates to each $t_i$.
- `+tv/+recon/fitSegment.m`: the residual vector, in the nested function `residuals`. It uses `lsqnonlin` with bounds $\lvert a_{1,2}\rvert \le 0.6$ and $0.3 \le C_D \le 0.8$, the Huber passes and the outlier cut.
- `+tv/+recon/initSegment.m`: the starting values. It triangulates the two cameras at camera 2's moments (camera 1 interpolated in time, never frames paired by index) and fits a parabola.
- `+tv/+recon/segments.m`: cuts a rally into flights at the track pieces' edges, then splits flights that hide an event, merges neighbours one flight explains, splits again, merges again, and drops junk.

## 4. Spin effect (TV-SPN-01) and spin rate (TV-SPN-03)

$$
\text{spin effect} = \big(\mathbf b_{\text{real}} - \mathbf b_{C_L = 0}\big)\cdot \hat{\mathbf d}
$$

Both bounce points come from the same start $\mathbf p_0, \mathbf v_0$, drag and wind. $\hat{\mathbf d}$ is the horizontal launch direction, so a negative value means the ball landed shorter than it would have without spin.

**Code:** `+tv/+metrics/shot.m`, the block headed "spin effect (TV-SPN-01)". The real bounce comes from the local function `segGround`, the no-spin one from `simulate` with `CL = 0`.

Spin rate: $C_L = \sqrt{a_1^2 + a_2^2}$. Then the spin parameter is $S = (C_L - 0.03)/0.51$ (the spec's initial table), $\omega = S\,\lvert\mathbf u_0\rvert / r$, and rpm $= 60\,\omega / 2\pi$, quoted $\pm 25\%$.

**Code:** `+tv/+metrics/spin.m`. Below $S = 0.1$ it reports "flat / low spin" with no rpm.

## 5. Air density (TV-AIR-03)

$$
\rho = \frac{p - p_v}{R_d T} + \frac{p_v}{R_v T}, \qquad p_v = \phi \cdot 610.94\, \exp\!\left(\frac{17.625\,T_C}{T_C + 243.04}\right)
$$

**Code:** `+tv/+air/density.m`. It is line for line the formula above, with $R_d$ = 287.05 and $R_v$ = 461.5 J/(kg·K), $T$ in kelvin and $T_C$ in °C. Pressure is the surface pressure from Open-Meteo, not sea level. `tests/airTest.m` checks it against reference values.

## 6. Time sync between the cameras (TV-SYNC-01 to 06)

Each detection's moment, in camera 1's clock:

$$
t = t_{\text{start}} + t_{\text{frame}} + \tau_r \frac{v - 1}{H} + \frac{t_{\text{shutter}}}{2}, \qquad
t \leftarrow t + \Delta + \varepsilon\,(t - t_{\text{ref}}) \;\text{(camera 2 only)}
$$

- $t_{\text{frame}}$ is the frame's own time stamp from the file, never $n$/fps.
- $v$ is the ball's image row, $\tau_r$ the readout time.
- $\Delta$ and $\varepsilon$ are camera 2's offset and drift.

**Code:** `+tv/+recon/detTimes.m`.

The three steps that set $\Delta$, $\varepsilon$ and $\tau_r$:
1. **Coarse:** the files' start times (`+tv/+pipeline/run.m`, local function `probeBoth`).
2. **Medium:** `+tv/+sync/fromRays.m`. It slides camera 2 by up to ±60 ms and keeps the offset at which the two cameras' sight lines to the ball come closest (median gap).
3. **Fine:** `+tv/+recon/refineSession.m`. It alternates between refitting every flight with the timing held, and fitting $\Delta$, $\varepsilon$, both $\tau_r$ and the wind per 15-minute window with the flights held. It has priors on $\tau_r$ (±1 ms) and $\varepsilon$ (±100 ppm), and a penalty on wind changes between windows.

TV-SYNC-06 (new): $\tau_r$ is measured outside play, from a flickering lamp's bands (`+tv/+sync/readoutFromBands.m`, `tools/readoutFromFlicker.m`). It fits
$\log I(n,v) = \text{row}(v) + \text{frame}(n) + B\sin\!\big(2\pi f (t_n + \tau_r v/H)\big) + \dots$, removing the row and frame levels exactly by centring.

## 7. Assumptions the code makes that the spec doesn't state

1. **The spin axis is fixed in space for a whole flight.** The spec says spin is constant within a flight (TV-PHY-02). The code also builds the two spin directions from the launch velocity over the ground, $\mathbf v_0$, not the velocity through the air, $\mathbf u_0$, and keeps that axis as the flight curves (`segmentModel.m`, `spinBasis.m`). With wind, the axis is then not exactly square to the air flow at launch. The truth model in the synthetic tests lets spin decay instead.
2. **The wind is constant over a flight**, taken from the 15-minute window the flight starts in, with no vertical wind (`refineSession.m`, local function `airAt`).
3. **"Fit jointly" is done by alternating** (`refineSession.m`). TV-PHY-03 asks for a joint fit of wind and session $C_D$ across shots. The code alternates flights and session parameters three times, and takes the session $C_D$ as the median of the flights' values rather than fitting it.
4. **Lift prior** (16 Nov, DECISIONS): every flight's $a_1, a_2$ have a prior centred on zero, sd 0.25, or 0.05 for flights shorter than 0.3 s. The spec has a prior only on $C_D$.
5. **The outlier cut and the split, merge and junk thresholds** (6 px, at most 10% of a flight; split if the fit is worse than 0.6 px and two flights fit 40% better; merge cap 3 px; junk above 5 px) are implementation choices, listed in VISION-RETUNE.md.
6. **Where the spin effect is measured from.** "The same start position and velocity" is taken as the flight's first fitted point (just after the hit), with the flight's own fitted drag and the session wind (`shot.m`). Contact is a few milliseconds earlier.
7. **Exposure time is the middle of the shutter**, $+t_{\text{shutter}}/2$, which the spec's formula leaves out. Rows count from 1, so the readout term is $\tau_r (v-1)/H$ against the spec's $\tau_r v/H$: one row's difference.
8. **The drift term applies to the whole detection time**, readout delay included. The spec writes $\varepsilon(t_2 - t_{\text{ref}})$ on the frame time. The difference is $\varepsilon\,\tau_r \approx$ 40 ppm × 8 ms, a third of a microsecond.
9. **The bounce sets a new flight** with new spin and drag fitted from scratch. The court model `+tv/+physics/bounce.m` (restitution 0.75, horizontal 0.65) is used only to make synthetic footage, never to measure.
10. **The net sags in a straight line** from post to centre (`+tv/+court/netHeight.m`), as the spec says. A real net hangs as a curve; the difference is under a centimetre.
11. **$g$ is 9.81 everywhere**, as the spec's drop test expects. The physics never takes the true local gravity, which differs by up to 0.3% with latitude.
