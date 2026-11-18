"""Colour-free ball proposals: small things that move. For frame t, the neighbours t-K and t+K are
lined up with t (whole-pixel shift by phase correlation), and a pixel moves when it differs from
both (so the ghost of where a thing was is not counted). The threshold is set from each frame's
own noise (median + N robust deviations), and blobs are kept only when their size fits a ball at
that place in the picture (the camera fit gives the diameter range). No colour anywhere."""
import numpy as np
from scipy import ndimage
import common

K = 2            # frames apart
NSIG = 8.0       # robust deviations above the frame's median motion
MIN_FLOOR = 18.0  # never below this (sum over RGB), so a still frame's sensor noise is not "motion"


def _grey_half(f):
    g = f[::2, ::2].astype(np.float32).mean(axis=2)
    return g - g.mean()


_WIN = np.outer(np.hanning(common.H // 2), np.hanning(common.W // 2)).astype(np.float32)


def shift(a, b):
    """Whole-pixel shift (dy, dx) that moves frame b onto frame a (full resolution)."""
    A = np.fft.rfft2(_grey_half(a) * _WIN); B = np.fft.rfft2(_grey_half(b) * _WIN)
    X = A * np.conj(B); c = np.fft.irfft2(X / np.maximum(np.abs(X), 1e-6), s=_WIN.shape)
    i = np.unravel_index(np.argmax(c), c.shape)
    dy, dx = [(v if v <= s // 2 else v - s) for v, s in zip(i, c.shape)]
    return 2 * dy, 2 * dx


def moved(f, dy, dx):
    return np.roll(np.roll(f, dy, axis=0), dx, axis=1)


R = 2            # shift tolerance, px: a difference a shift this small explains is not motion


def _tolerant(c, n):
    """Per pixel, the smallest difference between c and n shifted by up to R px (sum over RGB):
    edges and textures that only shimmer or sway by a pixel or two drop out; a ball that moved
    further than that does not."""
    best = None
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = np.abs(c - moved(n, dy, dx)).sum(axis=2)
            best = d if best is None else np.minimum(best, d)
    return best


import os
FAST = os.environ.get('TOLERANT', 'exact') == 'minmax'
SPARSE = os.environ.get('SPARSE', '1') == '1'   # the exact test, only at changed pixels (same result)
TAUF = float(os.environ.get('TAUF', '1'))   # the tolerant map's threshold as a share of tau


def _range_gap(c, n, R):
    """Per pixel, how far c lies outside the range of n's values within R px, per channel, summed
    over RGB: a lower bound of _tolerant (each channel may take its own shift), from two
    (2R+1)-square max and min filters per channel instead of (2R+1)^2 shifted differences."""
    size = (2 * R + 1, 2 * R + 1, 1)
    hi = ndimage.maximum_filter(n, size=size, mode='nearest'); lo = ndimage.minimum_filter(n, size=size, mode='nearest')
    return (np.maximum(c - hi, 0) + np.maximum(lo - c, 0)).sum(axis=2)


def _sparse_pair(cv, a, b, ys, xs, h, w):
    ba = bb = None
    for dy in range(-R, R + 1):
        yy = np.clip(ys - dy, 0, h - 1)
        for dx in range(-R, R + 1):
            xx = np.clip(xs - dx, 0, w - 1)
            da = np.abs(cv - a[yy, xx]).sum(axis=1); db = np.abs(cv - b[yy, xx]).sum(axis=1)
            ba = da if ba is None else np.minimum(ba, da); bb = db if bb is None else np.minimum(bb, db)
    return np.minimum(ba, bb)


def motion(prev, cur, nxt, floor=None):
    """Per-pixel motion of cur against both neighbours (lined up, shift-tolerant), sum over RGB.
    The shift-tolerant difference is only worked out where the plain one is already above
    `floor` (it can only be smaller), in tiles, which keeps it fast."""
    c = cur.astype(np.int16)
    sa, sb = shift(cur, prev), shift(cur, nxt)
    a = moved(prev, *sa).astype(np.int16)
    b = moved(nxt, *sb).astype(np.int16)
    plain = np.minimum(np.abs(c - a).sum(axis=2), np.abs(c - b).sum(axis=2)).astype(np.float32)
    # the strip a shift wraps round the frame's edge is not motion
    ey = max(abs(sa[0]), abs(sb[0])) + R; ex = max(abs(sa[1]), abs(sb[1])) + R
    plain[:ey] = 0; plain[plain.shape[0] - ey:] = 0; plain[:, :ex] = 0; plain[:, plain.shape[1] - ex:] = 0
    if floor is None: floor = MIN_FLOOR
    if callable(floor): floor = floor(plain)
    out = np.zeros_like(plain)
    T = 64
    hot = plain > floor
    if SPARSE and not FAST:
        # the shift-tolerant difference can only be smaller than the plain one, so it can pass the
        # threshold only where the plain one does; worked out there and one pixel round (closing
        # can add those), it gives the same blobs as the whole-tile version
        ys, xs = np.nonzero(ndimage.binary_dilation(hot, np.ones((3, 3), bool)))
        cv = c[ys, xs]; h, w = plain.shape
        if len(ys): out[ys, xs] = _sparse_pair(cv, a, b, ys, xs, h, w)
        out[:ey] = 0; out[out.shape[0] - ey:] = 0; out[:, :ex] = 0; out[:, out.shape[1] - ex:] = 0
        return out
    for ty, tx in zip(*np.nonzero(_tile_any(hot, T))):
        y0, x0 = ty * T, tx * T; y1, x1 = min(y0 + T, plain.shape[0]), min(x0 + T, plain.shape[1])
        Y0, X0 = max(0, y0 - R), max(0, x0 - R); Y1, X1 = min(plain.shape[0], y1 + R), min(plain.shape[1], x1 + R)
        cc = c[Y0:Y1, X0:X1]
        if FAST: m = np.minimum(_range_gap(cc, a[Y0:Y1, X0:X1], R), _range_gap(cc, b[Y0:Y1, X0:X1], R))
        else: m = np.minimum(_tolerant(cc, a[Y0:Y1, X0:X1]), _tolerant(cc, b[Y0:Y1, X0:X1]))
        out[y0:y1, x0:x1] = m[y0 - Y0:y0 - Y0 + (y1 - y0), x0 - X0:x0 - X0 + (x1 - x0)]
    out[:ey] = 0; out[out.shape[0] - ey:] = 0; out[:, :ex] = 0; out[:, out.shape[1] - ex:] = 0
    return out


def _tile_any(m, T):
    h, w = m.shape; H2, W2 = -(-h // T), -(-w // T)
    p = np.zeros((H2 * T, W2 * T), bool); p[:h, :w] = m
    return p.reshape(H2, T, W2, T).any(axis=(1, 3))


def proposals(prev, cur, nxt, dmin, dmax, mask):
    """Blobs that move and fit a ball's size here: rows [x, y, area, length, width, strength]."""
    st = {}

    def thresh(plain):
        # the frame's own noise, from the plain difference over where the ball can be
        m = plain[mask][::7]
        med = np.median(m); mad = np.median(np.abs(m - med)) * 1.4826 + 1e-3
        st['tau'] = max(MIN_FLOOR, med + NSIG * mad)
        return st['tau']
    M = motion(prev, cur, nxt, thresh)
    tau = st['tau']
    B = ndimage.binary_closing(M > tau * TAUF, structure=np.ones((3, 3))) & mask
    lab, n = ndimage.label(B, structure=np.ones((3, 3)))
    out = []
    if n == 0: return np.zeros((0, 6)), tau
    objs = ndimage.find_objects(lab)
    for k, sl in enumerate(objs, start=1):
        ys, xs = np.nonzero(lab[sl] == k)
        ys = ys + sl[0].start; xs = xs + sl[1].start
        area = len(xs)
        w = M[ys, xs]; x = (xs * w).sum() / w.sum(); y = (ys * w).sum() / w.sum()
        hy, hx = min(int(y) // 2, dmin.shape[0] - 1), min(int(x) // 2, dmin.shape[1] - 1)
        lo, hi = dmin[hy, hx], dmax[hy, hx]
        if hi <= 0: continue
        if area < 2: continue
        if len(xs) >= 3:
            C = np.cov(np.vstack([xs, ys])) + 0.25 * np.eye(2)
            ev = np.sort(np.linalg.eigvalsh(C))
            length, width = 4 * np.sqrt(ev[1]), 4 * np.sqrt(ev[0])
        else:
            length, width = float(area), 1.0
        # a ball: as wide as its diameter (with slack for blur and rounding), and as long as its
        # diameter plus motion blur (up to 8 diameters at the fastest)
        if width > 2.0 * hi + 2 or length > 9.0 * hi + 4: continue
        if area > np.pi / 4 * (2.0 * hi + 2) ** 2 * 4: continue
        out.append([x, y, area, length, width, float(w.max())])
    return np.array(out) if out else np.zeros((0, 6)), tau


def mask_full(v):
    dmin, dmax = common.geom(v)
    m = np.repeat(np.repeat(dmax > 0, 2, axis=0), 2, axis=1)[:common.H, :common.W]
    return m
