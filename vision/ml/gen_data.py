"""Training data for the ball classifier, from Chris's footage only (kept private).
Each sample: three 48 x 48 crops (frames t-K, t, t+K, lined up with t) and the ball's diameter
range there (from the camera fit). Negatives: the colour-free proposals of random frames (almost
all are not the ball). Positives: balls drawn into the same frames, at the size the camera gives
for that spot, in a wide range of colours and light (yellow, pale, near-white, dull, shaded), blurred
by their motion, and moving between the three frames as a ball at 5-45 m/s does. Test-set frames
and 2 s around them are never used."""
import numpy as np, sys, os, common, proposals as P

S = 48
rng = np.random.default_rng(int(sys.argv[2]) if __name__ == '__main__' and len(sys.argv) > 2 else 0)


def crop(F, x, y):
    """S x S crops of the three frames around (x, y), edge-padded."""
    x0 = int(round(x)) - S // 2; y0 = int(round(y)) - S // 2
    out = np.zeros((3, S, S, 3), np.uint8)
    for k in range(3):
        ys = np.clip(np.arange(y0, y0 + S), 0, common.H - 1); xs = np.clip(np.arange(x0, x0 + S), 0, common.W - 1)
        out[k] = F[k][np.ix_(ys, xs)]
    return out


def ball_colour():
    kind = rng.choice(['optic', 'pale', 'white', 'dull'], p=[0.4, 0.25, 0.15, 0.2])
    base = {'optic': (215, 235, 75), 'pale': (225, 230, 160), 'white': (235, 235, 225), 'dull': (170, 175, 105)}[kind]
    c = np.array(base, float) * rng.uniform(0.55, 1.15)
    c *= np.array([rng.uniform(0.85, 1.15), rng.uniform(0.9, 1.1), rng.uniform(0.8, 1.2)])   # tint of the light
    return np.clip(c, 0, 255)


def draw(img, cx, cy, D, col, vx, vy, blur):
    """Draws an anti-aliased, shaded ball of diameter D at (cx, cy) in img (float), smeared along
    (vx, vy) over `blur` of its per-frame motion."""
    r = D / 2
    n = max(1, int(np.ceil(blur * np.hypot(vx, vy) / 0.4)) + 1)     # a smooth streak, not copies
    acc = np.zeros(img.shape[:2]); colimg = np.zeros(img.shape)
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]].astype(float)
    sx, sy = rng.uniform(-0.5, 0.5, 2)            # direction of the light on the ball
    for k in range(n):
        f = (k / max(n - 1, 1) - 0.5) * blur
        px, py = cx + f * vx, cy + f * vy
        d = np.hypot(xx - px, yy - py)
        a = np.clip(r + 0.5 - d, 0, 1)
        shade = 1.0 + 0.25 * ((xx - px) * -sx + (yy - py) * -sy) / max(r, 0.5)
        acc += a / n
        colimg += (a / n)[..., None] * col[None, None, :] * np.clip(shade, 0.6, 1.3)[..., None]
    acc = np.clip(acc, 0, 1)
    with np.errstate(invalid='ignore', divide='ignore'):
        c = np.where(acc[..., None] > 0, colimg / np.maximum(acc[..., None], 1e-6), 0)
    return img * (1 - acc[..., None]) + c * acc[..., None]


def flight3d():
    """A ball in play: a point over the court and its run-off (low more often than high) and a
    tennis velocity: mostly along the court, 5-40 m/s, with some slow balls (tosses, lobs, drop
    shots) in any direction."""
    p = np.array([rng.uniform(-16.5, 16.5), rng.uniform(-6.8, 6.8), 0.05 + 3.5 * rng.random() ** 1.7])
    if rng.random() < 0.2:
        v = rng.normal(0, 1, 3); v = v / np.linalg.norm(v) * rng.uniform(0.5, 8)
    else:
        v = np.array([rng.choice([-1, 1]) * rng.uniform(5, 40), rng.normal(0, 3.5), rng.uniform(-9, 9)])
    return p, v


def positive(F, dmin, dmax, cam, ok_px):
    """A ball drawn into the three frames from a 3D flight, projected through the fitted camera:
    its position, size and motion in each frame are what that camera would see."""
    for _ in range(50):
        p, vel = flight3d()
        dt = P.K / common.FPS
        Ps = np.array([p - vel * dt + [0, 0, -0.5 * 9.81 * dt * dt], p, p + vel * dt + [0, 0, -0.5 * 9.81 * dt * dt]])
        q, ok = cam.project(Ps)
        if not ok.all(): continue
        x, y = q[1]
        if not (30 <= x < common.W - 30 and 30 <= y < common.H - 30) or not ok_px(x, y): continue
        dist = np.linalg.norm(Ps - cam.pos, axis=1)
        if dist.min() < 4: continue
        Ds = 2 * 0.0335 / dist * cam.fpx
        break
    else:
        return None, None
    lo, hi = dmin[int(y) // 2, int(x) // 2], dmax[int(y) // 2, int(x) // 2]
    # the motion within one exposure: the image velocity per frame times the exposure's share
    vimg = (q[2] - q[0]) / (2 * P.K)
    blur = rng.uniform(0.05, 0.9)
    col = ball_colour()
    C = crop(F, x, y).astype(float)
    out = np.empty_like(C)
    for k in range(3):
        cx = S / 2 - 0.5 + (q[k][0] - round(x)); cy = S / 2 - 0.5 + (q[k][1] - round(y))
        out[k] = draw(C[k], cx, cy, Ds[k] * rng.uniform(0.95, 1.05), col * rng.uniform(0.92, 1.08), vimg[0], vimg[1], blur)
    jitter = rng.integers(-1, 2, 2)                # the proposal's centre is not exactly the ball's
    out = np.roll(out, tuple(jitter), axis=(1, 2))
    return np.clip(out, 0, 255).astype(np.uint8), (lo, hi)


def frames_for(v, n):
    if v == 3: lo, hi = 10, 21600 - 10
    else: lo, hi = 10, len(common.pts(v)) - 10
    test = [lab['frame'] for (vv, i), lab in common.labels().items() if vv == v]
    pick = []
    while len(pick) < n:
        f = int(rng.integers(lo, hi))
        if all(abs(f - t) > 120 for t in test): pick.append(f)
    return pick


def main(v, n_frames, seed, out):
    dmin, dmax = common.geom(v); mask = P.mask_full(v)
    import physics
    cam = physics.Camera(v); cam.fpx = np.interp(0.01, cam.th, cam.rho) / 0.01   # px per radian near the axis
    ok_px = lambda x, y: mask[int(y), int(x)]
    X, M, Y = [], [], []
    for f in frames_for(v, n_frames):
        F5 = common.read(v, f - P.K, 2 * P.K + 1)
        if len(F5) < 2 * P.K + 1: continue
        cur = F5[P.K]
        prev = P.moved(F5[0], *P.shift(cur, F5[0])); nxt = P.moved(F5[2 * P.K], *P.shift(cur, F5[2 * P.K]))
        F = (prev, cur, nxt)
        if os.environ.get('POSONLY'):
            props = np.zeros((0, 6))
        else:
            props, _ = P.proposals(F5[0], cur, F5[2 * P.K], dmin, dmax, mask)
        if len(props) > 150: props = props[rng.choice(len(props), 150, replace=False)]
        for p in props:
            X.append(crop(F, p[0], p[1])); Y.append(0)
            M.append((dmin[min(int(p[1]) // 2, dmin.shape[0] - 1), min(int(p[0]) // 2, dmin.shape[1] - 1)],
                      dmax[min(int(p[1]) // 2, dmin.shape[0] - 1), min(int(p[0]) // 2, dmin.shape[1] - 1)]))
        for _ in range(int(os.environ.get('POSONLY', 0)) or max(60, len(props))):
            c, m = positive(F, dmin, dmax, cam, ok_px)
            if c is None: continue
            X.append(c); M.append(m); Y.append(1)
    np.savez_compressed(out, X=np.array(X), M=np.array(M, np.float32), Y=np.array(Y, np.uint8))
    print(out, len(Y), int(np.sum(Y)))


if __name__ == '__main__':
    main(int(sys.argv[1]), int(sys.argv[3]), int(sys.argv[2]), sys.argv[4])
