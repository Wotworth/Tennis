"""Round 5 self-training data from the detector's runs over new footage (detect_points.py chunks),
no hand labels. As mine2.py (balls: confident, smooth, not staying put; not balls: proposals far
from every ball path and not moving like a ball, plus slow points), with two additions:
- shadows: a ball example that is darker than its surround and shows no colour change (only a
  brightness change against both neighbour frames) is the ball's shadow. It is never a ball
  example and is taught as "not a ball" (the round-4 model follows shadows in strong sun);
- weak labels (mine_weak.py, where a SwingVision overlay exists): the points of a smooth path
  recovered at a bounce mark are ball examples whatever the classifier scored them.
Only chunks marked for training are used; the held-out stretches are never read here.
Usage: mine5.py V OVERLAY_DIR DETECTIONS_DIR [WEAK.npz]   (env VIDEO_W, VIDEO_H; TRAIN_UNTIL frame)"""
import sys, os, csv, glob, numpy as np, multiprocessing as mp
import common, proposals as P, gen_data as G, tracker as T, mine2
from detect_video import stream

SHADOW_DARK, SHADOW_RATIO = -0.2, 0.3


def features(X):
    """Per crop set (n, 3, 48, 48, 3): the middle's brightness against the surround (in units of the
    cut's contrast), and the share of its change against the neighbour frames that is a change of
    colour rather than of brightness."""
    x = X.astype(np.float32) / 255; g = x.mean(-1)
    sd = np.maximum(g[:, 1].reshape(len(X), -1).std(1), 0.03)
    c = slice(21, 27); ring = np.ones((48, 48), bool); ring[14:34, 14:34] = False
    contrast = (g[:, 1, c, c].mean((1, 2)) - np.median(g[:, 1][:, ring], axis=1)) / sd

    def rem(a, b):
        k = (a * b).sum(-1) / ((b * b).sum(-1) + 3 * 0.02 ** 2)
        return np.abs(a - k[..., None] * b).mean(-1)[:, c, c].mean((1, 2))
    col = np.maximum(rem(x[:, 1], x[:, 0]), rem(x[:, 1], x[:, 2]))
    chg = np.maximum(np.abs(x[:, 1] - x[:, 0]).mean(-1)[:, c, c].mean((1, 2)), np.abs(x[:, 1] - x[:, 2]).mean(-1)[:, c, c].mean((1, 2)))
    return contrast, col / np.maximum(chg, 1e-6)


def one(args):
    v, f, weak = args
    out = f.replace('.npy', '_mine5.npz')
    if os.path.exists(out): return out
    rng = np.random.default_rng(abs(hash(os.path.basename(f))) % 2 ** 32)
    D = np.load(f)
    if len(D) == 0: return out
    Ds, ch = T.chains(D[D[:, 3] > 0.05])
    keep = []; still = []
    for val, p in ch:
        sl = mine2.slow_points(Ds[p])
        if sl.any(): still.append(p[sl])
        if val >= mine2.POS_VALUE and len(p) >= mine2.POS_LEN:
            g = mine2.smooth_points(Ds[p]) & ~sl
            if g.any(): keep.append(p[g])
    pos = Ds[np.concatenate(keep)] if keep else np.zeros((0, D.shape[1]))
    if weak is not None and len(weak): pos = np.concatenate([pos, weak[:, :D.shape[1]]])
    still = Ds[np.concatenate(still)] if still else np.zeros((0, D.shape[1]))
    allc = np.concatenate([Ds[p][:, :3] for _, p in ch] + ([weak[:, :3]] if weak is not None and len(weak) else [])) if ch else np.zeros((0, 3))
    far = ~mine2.smooth_movers(D)
    order = np.argsort(allc[:, 0]) if len(allc) else np.zeros(0, int); allc = allc[order]
    for fr in np.unique(D[:, 0]):
        near = allc[np.searchsorted(allc[:, 0], fr - 3):np.searchsorted(allc[:, 0], fr + 3, side='right')]
        if not len(near): continue
        k = np.nonzero(D[:, 0] == fr)[0]
        d = np.hypot(D[k, 1][:, None] - near[:, 1][None], D[k, 2][:, None] - near[:, 2][None]).min(1)
        far[k[d < 40]] = False
    rows = []
    for fr in np.unique(D[:, 0]):
        k = np.nonzero(far & (D[:, 0] == fr))[0]
        hard = k[D[k, 3] > 0.3]; rest = k[D[k, 3] <= 0.3]
        rows += list(hard) + list(rng.choice(rest, min(int(os.environ.get('NEG_PER_FRAME', 3)), len(rest)), replace=False))
    neg = np.concatenate([D[np.array(rows, int)], still])
    want = {}
    for r, y in [(r, 1) for r in pos] + [(r, 0) for r in neg]: want.setdefault(int(r[0]), []).append((r, y))
    X, M, Y = [], [], []
    f0, f1 = int(D[:, 0].min()), int(D[:, 0].max()); buf = {}
    for k, fimg in enumerate(stream(v, f0 - P.K, f1 - f0 + 1 + 2 * P.K)):
        fr = f0 - P.K + k; buf[fr] = fimg; c = fr - P.K; buf.pop(c - P.K - 1, None)
        if c not in want or c - P.K not in buf: continue
        cur = buf[c]; pa = P.moved(buf[c - P.K], *P.shift(cur, buf[c - P.K])); na = P.moved(buf[c + P.K], *P.shift(cur, buf[c + P.K]))
        for r, y in want[c]:
            sc = G.scale_of(r[6], r[7], r[8])
            X.append(G.crop((pa, cur, na), r[1], r[2], sc)); M.append(r[7:9] / sc); Y.append(y)
    X = np.array(X, np.uint8).reshape(-1, 3, 48, 48, 3); M = np.array(M, np.float32).reshape(-1, 2); Y = np.array(Y, np.uint8)
    S = np.zeros(len(Y), bool)
    if len(Y):
        contrast, ratio = features(X)
        S = (Y == 1) & (contrast < SHADOW_DARK) & (ratio < SHADOW_RATIO)
        Y[S] = 0
    np.savez_compressed(out, X=X, M=M, Y=Y, S=S)
    print(os.path.basename(out), 'balls', int(Y.sum()), 'not balls', int((Y == 0).sum()), 'of which shadows', int(S.sum()), flush=True)
    return out


if __name__ == '__main__':
    v, ovl, det = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    weak = np.load(sys.argv[4])['rows'] if len(sys.argv) > 4 else None
    until = int(os.environ.get('TRAIN_UNTIL', 10 ** 9))
    jobs = []
    for p in csv.DictReader(open(f'{ovl}/v{v}_points.csv')):
        if p.get('use', 'train') != 'train' or int(p['last']) >= until: continue
        f = f'{det}/v{v}_p{int(p["point"]):03d}.npy'
        if not os.path.exists(f): continue
        w = None
        if weak is not None:                      # the recovered paths only (flag 1): the tracked ones come from the chains
            w = weak[(weak[:, 12] == int(p['point'])) & (weak[:, 14] == 1)]
        jobs.append((v, f, w))
    with mp.Pool(int(os.environ.get('WORKERS', 4))) as pool:
        pool.map(one, jobs, chunksize=1)
    print('mining done', len(jobs), 'chunks')
