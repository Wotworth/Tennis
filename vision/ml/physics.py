"""The physics judge (one camera): a chain of detections is the ball in play only if a flight under
gravity (with air drag) over the court of interest, seen through the fitted camera, explains it to
within a pixel or two. Gravity fixes the scale, so even one camera can tell a real flight from a
racquet, an arm, a shirt or a ball on the next court."""
import numpy as np
from scipy.optimize import least_squares
import common

G = 9.81
KDRAG = 0.012      # 1/m: ball drag deceleration = KDRAG * |v| * v (about 0.55 C_D rho A / m)


class Camera:
    def __init__(self, v):
        a = np.fromfile(f'{common.ROOT}/ml/cam_v{v}.f64', dtype=np.float64)
        self.R = a[0:9].reshape(3, 3, order='F'); self.pos = a[9:12]
        self.w, self.h = a[12], a[13]; n = int(a[14])
        self.th = a[15:15 + n]; self.rho = a[15 + n:15 + 2 * n]

    def project(self, P):
        Q = np.atleast_2d(P) - self.pos
        Xc, Yc, Zc = Q @ self.R[0], Q @ self.R[1], Q @ self.R[2]
        r = np.hypot(Xc, Yc); th = np.arctan2(r, Zc)
        rho = np.interp(th, self.th, self.rho, right=np.nan)
        r = np.where(r == 0, 1e-12, r)
        u = rho * Xc / r + (self.w + 1) / 2; v = rho * Yc / r + (self.h + 1) / 2
        return np.stack([u, v], axis=1), (Zc > 0) & np.isfinite(rho)

    def ray(self, u, v):
        """Unit sight line through pixel (u, v), court axes."""
        du, dv = u - (self.w + 1) / 2, v - (self.h + 1) / 2
        rho = np.hypot(du, dv); th = np.interp(rho, self.rho, self.th)
        d = np.array([np.sin(th) * du / max(rho, 1e-9), np.sin(th) * dv / max(rho, 1e-9), np.cos(th)])
        return d @ self.R


def flight(p0, v0, t):
    """Positions at times t (s, from 0) under gravity and quadratic drag (small steps)."""
    out = np.empty((len(t), 3)); p = p0.astype(float).copy(); v = v0.astype(float).copy(); now = 0.0
    order = np.argsort(t); dt_max = 1 / 240
    for k in order:
        while now < t[k] - 1e-9:
            h = min(dt_max, t[k] - now)
            a = np.array([0, 0, -G]) - KDRAG * np.linalg.norm(v) * v
            p += v * h + 0.5 * a * h * h; v += a * h; now += h
        out[k] = p
    return out


def fit(cam, t, uv, box):
    """Best flight through the points (t in s, uv in px). Returns (rms px, p0, v0, ok)."""
    t = np.asarray(t, float) - t[0]; uv = np.asarray(uv, float)
    best = (np.inf, None, None)
    r0 = cam.ray(*uv[0]); r1 = cam.ray(*uv[-1]); T = max(t[-1], 1e-3)
    for d0 in (6, 10, 15, 21, 28):
        for d1 in (6, 10, 15, 21, 28):
            p0 = cam.pos + d0 * r0; p1 = cam.pos + d1 * r1
            v0 = (p1 - p0) / T + np.array([0, 0, 0.5 * G * T])
            if p0[2] < -0.5 or p0[2] > 12: continue

            def res(x):
                P = flight(x[:3], x[3:], t)
                q, ok = cam.project(P)
                e = (q - uv).ravel()
                return np.where(np.isfinite(e), e, 1e3)
            try:
                s = least_squares(res, np.r_[p0, v0], method='lm', max_nfev=200)
            except Exception:
                continue
            rms = np.sqrt(np.mean(s.fun ** 2))
            if rms < best[0]: best = (rms, s.x[:3], s.x[3:])
    rms, p0, v0 = best
    if p0 is None: return np.inf, None, None, False
    P = flight(p0, v0, t)
    inside = (np.abs(P[:, 0]) <= box[0]) & (np.abs(P[:, 1]) <= box[1]) & (P[:, 2] >= -0.3) & (P[:, 2] <= box[2])
    speed = np.linalg.norm(v0)
    ok = inside.mean() >= 0.8 and 3 <= speed <= 75
    return rms, p0, v0, ok


BOX = (11.885 + 5, 5.485 + 2, 12)    # the court of interest: 5 m behind baselines, 2 m past doubles lines, 12 m up
