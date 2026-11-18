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


BALL_PX = 6.0      # the ball's diameter in the classifier's input, whatever the camera or distance
SIDE_MIN, SIDE_MAX = 24.0, 192.0


def scale_of(width, dmin, dmax):
    """The ball's likely diameter (px) at a proposal: its blob's width, kept within what the
    camera's geometry allows there."""
    return float(np.clip(max(width, 2.0), max(dmin, 1.0), max(dmax, max(dmin, 1.0))))


def side_of(s):
    """Side (px, in the frame) of the square cut out for a ball of diameter s: S / BALL_PX
    diameters, so the ball is BALL_PX px across once the square is resampled to S x S."""
    return float(np.clip(s * S / BALL_PX, SIDE_MIN, SIDE_MAX))


def resample(img, cx, cy, side, n=None):
    """The square of `side` px centred on (cx, cy) (0-based pixel centres) of img (H, W, C),
    resampled to n x n (default S): bilinear, edge-clamped, averaged over a 2 x 2 grid per output
    pixel when shrinking. Written out so the MATLAB twin (tv.detect.ballCrops) is identical."""
    n = n or S
    ss = 2 if side > n else 1
    g = n * ss
    o = ((np.arange(g) + 0.5) / g - 0.5) * side
    h, w = img.shape[:2]
    u = np.clip(cx + o, 0, w - 1); v = np.clip(cy + o, 0, h - 1)
    u0 = np.floor(u).astype(int); v0 = np.floor(v).astype(int)
    u1 = np.minimum(u0 + 1, w - 1); v1 = np.minimum(v0 + 1, h - 1)
    fu = (u - u0)[None, :, None]; fv = (v - v0)[:, None, None]
    # (only the pixels needed are converted: converting the whole frame for every cut cost 20 ms)
    a = img[np.ix_(v0, u0)].astype(np.float64); b = img[np.ix_(v0, u1)].astype(np.float64)
    c = img[np.ix_(v1, u0)].astype(np.float64); d = img[np.ix_(v1, u1)].astype(np.float64)
    out = (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv
    if ss > 1: out = out.reshape(n, ss, n, ss, -1).mean(axis=(1, 3))
    return out


def crop_batch(F, xs, ys, scs):
    """crop() for many spots of one frame triple at once (same numbers, far fewer Python calls):
    returns (n, 3, S, S, 3) uint8."""
    n_ = len(xs); out = np.zeros((n_, 3, S, S, 3), np.uint8)
    sides = np.array([side_of(q) for q in scs]); h, w = F[0].shape[:2]
    for ss in (1, 2):
        k = np.nonzero((sides > S) == (ss == 2))[0]
        if not len(k): continue
        g = S * ss
        o = ((np.arange(g) + 0.5) / g - 0.5)[None, :] * sides[k, None]
        u = np.clip(np.asarray(xs, float)[k, None] + o, 0, w - 1); v = np.clip(np.asarray(ys, float)[k, None] + o, 0, h - 1)
        u0 = np.floor(u).astype(int); v0 = np.floor(v).astype(int)
        u1 = np.minimum(u0 + 1, w - 1); v1 = np.minimum(v0 + 1, h - 1)
        fu = (u - u0)[:, None, :, None]; fv = (v - v0)[:, :, None, None]
        for f in range(3):
            img = F[f]
            a = img[v0[:, :, None], u0[:, None, :]].astype(np.float64); b = img[v0[:, :, None], u1[:, None, :]].astype(np.float64)
            c = img[v1[:, :, None], u0[:, None, :]].astype(np.float64); d = img[v1[:, :, None], u1[:, None, :]].astype(np.float64)
            r = (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv
            if ss > 1: r = r.reshape(len(k), S, ss, S, ss, -1).mean(axis=(2, 4))
            out[k, f] = np.clip(r + 0.5, 0, 255).astype(np.uint8)
    return out


def crop(F, x, y, s):
    """The classifier's input for a spot at (x, y) with likely ball diameter s: the three frames,
    each S x S x 3 uint8, cut so the ball is BALL_PX px across."""
    side = side_of(s)
    return np.clip(np.stack([resample(F[k], x, y, side) for k in range(3)]) + 0.5, 0, 255).astype(np.uint8)


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
    # the scale a proposal would give: about the ball's diameter, within the geometry's range
    sc = scale_of(Ds[1] * rng.uniform(0.75, 1.3), lo, hi); side = side_of(sc)
    # the spot's centre is not exactly the ball's
    cx0, cy0 = x + rng.uniform(-0.2, 0.2) * sc, y + rng.uniform(-0.2, 0.2) * sc
    # drawn at the frame's own resolution when the cut is small (a far ball stays as soft as a real
    # one after enlarging), at the input's resolution when it is large
    n = int(round(side)) if side <= S else S
    g = n / side                                   # work pixels per frame pixel
    vimg = (q[2] - q[0]) / (2 * P.K) * g           # image velocity per frame, in work pixels
    blur = rng.uniform(0.05, 0.9)
    col = ball_colour()
    out = np.empty((3, S, S, 3), np.float32)
    for k in range(3):
        patch = resample(F[k], cx0, cy0, side, n)
        px = (q[k][0] - cx0) * g + n / 2 - 0.5; py = (q[k][1] - cy0) * g + n / 2 - 0.5
        patch = draw(patch.astype(float), px, py, Ds[k] * g * rng.uniform(0.95, 1.05), col * rng.uniform(0.92, 1.08), vimg[0], vimg[1], blur)
        out[k] = patch if n == S else resample(patch, n / 2 - 0.5, n / 2 - 0.5, n)
    return np.clip(out + 0.5, 0, 255).astype(np.uint8), (lo / sc, hi / sc)


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
            lo = dmin[min(int(p[1]) // 2, dmin.shape[0] - 1), min(int(p[0]) // 2, dmin.shape[1] - 1)]
            hi = dmax[min(int(p[1]) // 2, dmin.shape[0] - 1), min(int(p[0]) // 2, dmin.shape[1] - 1)]
            sc = scale_of(p[4], lo, hi)
            X.append(crop(F, p[0], p[1], sc)); Y.append(0); M.append((lo / sc, hi / sc))
        for _ in range(int(os.environ.get('POSONLY', 0)) or max(60, len(props))):
            c, m = positive(F, dmin, dmax, cam, ok_px)
            if c is None: continue
            X.append(c); M.append(m); Y.append(1)
    np.savez_compressed(out, X=np.array(X), M=np.array(M, np.float32), Y=np.array(Y, np.uint8))
    print(out, len(Y), int(np.sum(Y)))


if __name__ == '__main__':
    main(int(sys.argv[1]), int(sys.argv[3]), int(sys.argv[2]), sys.argv[4])
