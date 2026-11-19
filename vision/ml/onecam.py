"""Flights from one camera (the Python twin of tv.recon.initOneCam and the one-camera fit in
tv.recon.fitSegment, without pins): a ball's flight seen by a single fitted camera is found from
its sight lines and the physics alone, because gravity sets the scale. Used to split a tracked
ball's path into flights: a hit or a bounce is where one flight cannot explain both sides.

  init_linear   gravity only: least squares on the sight lines (linear in start and velocity)
  fit_flight    gravity, drag and one lift number (topspin + / slice -), Levenberg-Marquardt
  flights       candidate cuts merged back while one flight explains both neighbours"""
import numpy as np

G = 9.81
KDRAG = 0.012          # 1/m, as physics.py
H = 1 / 120            # integration step, s


def rays(cam, uv):
    return np.stack([cam.ray(u, v) for u, v in uv])


def init_linear(cam, t, uv):
    """Start position and velocity at t[0] from the sight lines under gravity alone."""
    d = rays(cam, uv); tau = t - t[0]; n = len(t)
    M = np.zeros((3 * n, 6)); b = np.zeros(3 * n)
    for i in range(n):
        K = np.array([[0, -d[i, 2], d[i, 1]], [d[i, 2], 0, -d[i, 0]], [-d[i, 1], d[i, 0], 0]])
        M[3 * i:3 * i + 3, :3] = K; M[3 * i:3 * i + 3, 3:] = K * tau[i]
        b[3 * i:3 * i + 3] = K @ (cam.pos - np.array([0, 0, -G]) * tau[i] ** 2 / 2)
    x = np.linalg.lstsq(M, b, rcond=None)[0]
    return x[:3], x[3:]


def simulate(X, tau):
    """Positions (m, n, 3) of m flights X = [p0 v0 cl] at times tau (n, from 0): gravity, drag and
    a lift across the path in the vertical plane, midpoint steps of H."""
    m = len(X); p = X[:, :3].copy(); v = X[:, 3:6].copy(); cl = X[:, 6:7]
    steps = int(np.ceil(max(tau[-1], 0) / H)) + 1
    P = np.empty((steps + 1, m, 3)); P[0] = p

    def acc(v):
        s = np.linalg.norm(v, axis=1, keepdims=True)
        side = np.stack([v[:, 1], -v[:, 0], np.zeros(m)], axis=1)                 # level, across the path
        down = np.cross(v, side); down /= np.maximum(np.linalg.norm(down, axis=1, keepdims=True), 1e-9)   # across the path, downward for topspin
        return np.array([0, 0, -G]) - KDRAG * s * v + KDRAG * cl * s * s * down
    for k in range(steps):
        a1 = acc(v); vm = v + a1 * H / 2; a2 = acc(vm)
        p = p + vm * H; v = v + a2 * H; P[k + 1] = p
    f = np.clip(tau / H, 0, steps - 1e-9); i = f.astype(int); w = (f - i)[:, None, None]
    return np.transpose(P[i] * (1 - w) + P[i + 1] * w, (1, 0, 2))


def _lm(cam, tau, uv, x, iters, cl_sd):
    step = np.array([0.01, 0.01, 0.01, 0.02, 0.02, 0.02, 0.05]); lam = 1e-2

    def res(X):
        P = simulate(X, tau); q, ok = cam.project(P.reshape(-1, 3))
        e = (q.reshape(len(X), -1, 2) - uv).reshape(len(X), -1)
        e = np.where(np.isfinite(e), e, 1e3)
        return np.concatenate([e, X[:, 6:7] / cl_sd], axis=1)
    r = res(x[None])[0]; cost = r @ r
    for _ in range(iters):
        J = ((res(x[None] + np.diag(step)) - r) / step[:, None]).T
        A = J.T @ J; g = J.T @ r; done = False
        for _try in range(6):
            try: dx = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
            except np.linalg.LinAlgError: lam *= 10; continue
            r2 = res((x + dx)[None])[0]; c2 = r2 @ r2
            if c2 < cost:
                done = cost - c2 < 1e-6 * cost; x, r, lam, cost = x + dx, r2, lam / 3, c2; break
            lam *= 10
        else: break
        if done: break
    e = r[:-1].reshape(-1, 2)
    return float(np.sqrt(np.mean(np.sum(e ** 2, axis=1)))), x


def _plausible(x):
    return abs(x[0]) < 30 and abs(x[1]) < 15 and -0.5 < x[2] < 12 and 1 <= np.linalg.norm(x[3:6]) <= 80


def fit_flight(cam, t, uv, iters=12, cl_sd=0.3):
    """One flight through the detections: (rms px, x = [p0 v0 cl], ok). cl is held near 0 (its
    prior costs one pixel per cl_sd), since one camera sees spin only weakly. The start comes
    from the linear solve; seen from behind the baseline the distance along the sight line is
    weakly fixed and that solve can land somewhere impossible, so when it or its fit is no good
    the fit is restarted from a few distances along the first and last sight lines."""
    t = np.asarray(t, float); uv = np.asarray(uv, float); tau = t - t[0]
    if len(t) < 4: return np.inf, None, False
    best = (np.inf, None)
    try:
        p0, v0 = init_linear(cam, t, uv); x = np.r_[p0, v0, 0.0]
        if _plausible(x): best = _lm(cam, tau, uv, x, iters, cl_sd)
    except Exception: pass
    if not (best[0] < 1.0 and _plausible(best[1])):
        r0, r1 = cam.ray(*uv[0]), cam.ray(*uv[-1]); T = max(tau[-1], 1e-3)
        for d0 in (8.0, 16.0, 26.0):
            for d1 in (8.0, 16.0, 26.0):
                p0 = cam.pos + d0 * r0; p1 = cam.pos + d1 * r1
                x = np.r_[p0, (p1 - p0) / T + np.array([0, 0, 0.5 * G * T]), 0.0]
                if not _plausible(x): continue
                c = _lm(cam, tau, uv, x, iters, cl_sd)
                if c[0] < best[0] and _plausible(c[1]): best = c
                if best[0] < 1.0: break
            if best[0] < 1.0: break
    rms, x = best
    return rms, x, bool(x is not None and np.isfinite(rms))


def flights(cam, f, uv, cuts, fps=60.0, merge_rms=1.5, cap=3.0, min_pts=5):
    """Split a track (frames f, pixels uv) at candidate cuts, then merge neighbours while one
    flight explains both (as tv.recon.segments). Returns [(first index, last index, rms, x)]."""
    t = f / fps
    edges = [0] + [int(np.searchsorted(f, c)) for c in sorted(cuts)] + [len(f)]
    edges = sorted(set(edges))
    segs = []
    for a, b in zip(edges[:-1], edges[1:]):
        if b - a < 1: continue
        rms, x, ok = fit_flight(cam, t[a:b], uv[a:b]) if b - a >= min_pts else (np.inf, None, False)
        segs.append([a, b, rms, x])
    cache = {}

    def joint(a, b):
        key = (a[0], b[1])
        if key not in cache: cache[key] = fit_flight(cam, t[a[0]:b[1]], uv[a[0]:b[1]])
        return cache[key]
    while len(segs) > 1:
        best = None                                   # the pair whose joint flight fits best goes first
        for k in range(len(segs) - 1):
            a, b = segs[k], segs[k + 1]
            if b[1] - a[0] < min_pts: continue
            rms, x, ok = joint(a, b)
            known = [r for r in (a[2], b[2]) if np.isfinite(r)]
            limit = min(max(merge_rms, 1.5 * max(known)), cap) if known else merge_rms
            if ok and rms < limit and (best is None or rms < best[1]): best = (k, rms, x)
        if not best: break
        k, rms, x = best
        segs[k:k + 2] = [[segs[k][0], segs[k + 1][1], rms, x]]
    return [tuple(s) for s in segs]
