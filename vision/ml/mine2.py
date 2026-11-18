"""Self-training data from one detector run over a stretch (mine_runs.py), no labels used:
- real balls: points of confident chains (worth >= POS_VALUE, >= POS_LEN frames) that lie on a
  smooth stretch of flight: some run of 9 consecutive chain points around them fits a quadratic in
  time within FIT_PX + 0.3 diameters (RMS). Chains run through hits and bounces, so a whole
  chain is never one curve.
- not balls: every proposal scored > 0.3 that is far from all chains (hard), plus NEG_PER_FRAME
  random others far from all chains. Far: over 40 px from any chain point within 3 frames, and
  not a smooth mover whatever its score (a point with points k frames before and after, k = 1-3,
  on a straight line at a steady speed): a real ball the classifier misses must never be taught
  as "not a ball" (the first models learned exactly that from their training videos).
Crops are cut in a second straight read of the stretch."""
import numpy as np, sys, os, glob, multiprocessing as mp, common, proposals as P, gen_data as G, tracker as T
from scipy.spatial import cKDTree
from detect_video import stream

POS_VALUE, POS_LEN, FIT_PX, NEG_PER_FRAME = 20.0, 15, 1.5, 10


def smooth(rows):
    t = rows[:, 0] - rows[0, 0]
    A = np.vstack([np.ones_like(t), t, t ** 2]).T
    res = []
    for c in (1, 2):
        coef, *_ = np.linalg.lstsq(A, rows[:, c], rcond=None)
        res.append(rows[:, c] - A @ coef)
    rms = np.sqrt(np.mean(np.hypot(*res) ** 2))
    return rms <= FIT_PX + 0.3 * np.median(0.5 * (rows[:, 7] + rows[:, 8])), rms


def smooth_points(rows, n=9):
    good = np.zeros(len(rows), bool)
    for a in range(0, len(rows) - n + 1):
        ok, _ = smooth(rows[a:a + n])
        if ok: good[a:a + n] = True
    return good


SLOW_FRAMES, SLOW_DIAM = 30, 3.0


def slow_points(rows):
    """True for chain points that stay put for a second: every chain point within SLOW_FRAMES
    frames (0.5 s) either side lies within SLOW_DIAM of the smallest ball diameter possible there,
    and those points span at least 0.8 s. A ball in flight never does: gravity alone moves it over
    a metre in that time (at the top of a lob it stays within a few pixels for a sixth of a second,
    not for a second). A blinking light, a curtain fold, the net, a logo on a player standing still
    and a ball lying or held still do. Such points are never ball examples and are taught as
    "not a ball" (round 3)."""
    out = np.zeros(len(rows), bool); f = rows[:, 0]
    for i in range(len(rows)):
        k = np.abs(f - f[i]) <= SLOW_FRAMES
        if f[k].max() - f[k].min() < 1.6 * SLOW_FRAMES: continue
        ext = np.hypot(rows[k, 1] - rows[i, 1], rows[k, 2] - rows[i, 2]).max()
        out[i] = ext <= SLOW_DIAM * max(rows[i, 7], 3.0)
    return out


def smooth_movers(D, tol0=1.5, tolk=0.1):
    """True for proposals that move steadily over five frames: proposals at t-2, t-1, t+1 and
    t+2 sit where a steady speed puts them (within tol0 px + tolk of the step, a step of at least
    1 px a frame and at most a ball's top speed there)."""
    out = np.zeros(len(D), bool)
    fr = D[:, 0].astype(int); by = {f: np.nonzero(fr == f)[0] for f in np.unique(fr)}
    trees = {f: cKDTree(D[i, 1:3]) for f, i in by.items()}
    for f, idx in by.items():
        if any(f + k not in by for k in (-2, -1, 1, 2)): continue
        A = D[by[f - 1], 1:3]
        for j in idx:
            p = D[j, 1:3]; vmax = 12 * max(0.5 * (D[j, 7] + D[j, 8]), 3) + 6
            v = p - A; sp = np.hypot(*v.T); ok = (sp >= 1) & (sp <= vmax)
            if not ok.any(): continue
            v = v[ok]; tol = tol0 + tolk * sp[ok]
            good = np.ones(len(v), bool)
            for k, base in ((1, p), (2, p), (-2, p)):
                d, _ = trees[f + k].query(base + k * v)
                good &= d <= tol * abs(k)
            if good.any(): out[j] = True
    return out


def one(f):
    out = f.replace('.npy', os.environ.get('MINE_SUFFIX', '_mine') + '.npz')
    if os.path.exists(out): return out
    rng = np.random.default_rng(abs(hash(os.path.basename(f))) % 2 ** 32)
    v = int(os.path.basename(f)[1]); s = int(os.path.basename(f)[3:9])
    D = np.load(f)
    pos, neg = np.zeros((0, D.shape[1])), np.zeros((0, D.shape[1]))
    if len(D):
        Ds, ch = T.chains(D[D[:, 3] > 0.05])
        keep = []; still = []
        for val, p in ch:
            sl = slow_points(Ds[p])
            if sl.any(): still.append(p[sl])
            if val >= POS_VALUE and len(p) >= POS_LEN:
                g = smooth_points(Ds[p]) & ~sl
                if g.any(): keep.append(p[g])
        pos = Ds[np.concatenate(keep)] if keep else pos
        still = Ds[np.concatenate(still)] if still else np.zeros((0, D.shape[1]))
        allc = np.concatenate([Ds[p][:, :3] for _, p in ch]) if ch else np.zeros((0, 3))
        far = ~smooth_movers(D)
        for i, r in enumerate(D):
            near = allc[np.abs(allc[:, 0] - r[0]) <= 3]
            if len(near) and np.min(np.hypot(near[:, 1] - r[1], near[:, 2] - r[2])) < 40: far[i] = False
        rows = []
        for fr in np.unique(D[:, 0]):
            k = np.nonzero(far & (D[:, 0] == fr))[0]
            hard = k[D[k, 3] > 0.3]; rest = k[D[k, 3] <= 0.3]
            rows += list(hard) + list(rng.choice(rest, min(NEG_PER_FRAME, len(rest)), replace=False))
        neg = np.concatenate([D[np.array(rows, int)], still])
    X, M, Y = [], [], []
    want = {}
    for r, y in [(r, 1) for r in pos] + [(r, 0) for r in neg]: want.setdefault(int(r[0]), []).append((r, y))
    buf = {}
    for k, fimg in enumerate(stream(v, s - P.K, 240 + 2 * P.K)):
        fr = s - P.K + k; buf[fr] = fimg; c = fr - P.K; buf.pop(c - P.K - 1, None)
        if c not in want or c - P.K not in buf: continue
        cur = buf[c]; pa = P.moved(buf[c - P.K], *P.shift(cur, buf[c - P.K])); na = P.moved(buf[c + P.K], *P.shift(cur, buf[c + P.K]))
        for r, y in want[c]:
            X.append(G.crop((pa, cur, na), r[1], r[2])); M.append(r[7:9]); Y.append(y)
    np.savez_compressed(out, X=np.array(X, np.uint8).reshape(-1, 3, 48, 48, 3), M=np.array(M, np.float32).reshape(-1, 2), Y=np.array(Y, np.uint8))
    print(os.path.basename(out), 'balls', int(np.sum(Y)), 'not balls', len(Y) - int(np.sum(Y)), flush=True)
    return out


if __name__ == '__main__':
    files = sorted(f for f in glob.glob(sys.argv[1]) if f.endswith('.npy'))
    with mp.Pool(4) as p:
        p.map(one, files, chunksize=1)
    print('all done')
