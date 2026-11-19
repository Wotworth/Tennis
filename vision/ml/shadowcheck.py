"""Does 'the colour changed, not only the brightness' tell a ball from its shadow? On spots checked by eye."""
import sys, numpy as np, common, proposals as P, gen_data as G, tracker, glob
v = int(sys.argv[1]); picks = eval(sys.argv[2])       # [(frame, 'ball' | 'shadow'), ...]
files = sorted(glob.glob(sys.argv[3]))
def resid(a, b):
    a = a.astype(np.float32) / 255; b = b.astype(np.float32) / 255
    s = (a * b).sum(-1) / ((b * b).sum(-1) + 3 * 0.02 ** 2)
    return np.abs(a - s[..., None] * b).mean(-1)
for f, what in picks:
    for path in files:
        D = np.load(path)
        if not (D[:, 0].min() <= f <= D[:, 0].max()): continue
        D = D[D[:, 3] > 0.05]; Ds, ch = tracker.chains(D); ball = tracker.ball_per_frame(Ds, ch)
        if f not in ball: break
        x, y = ball[f]; row = Ds[np.argmin(np.abs(Ds[:, 0] - f) * 1e6 + np.hypot(Ds[:, 1] - x, Ds[:, 2] - y))]
        F = common.read(v, f - P.K, 2 * P.K + 1); prev, cur, nxt = F[0], F[P.K], F[2 * P.K]
        sc = G.scale_of(row[6], row[7], row[8]); X = G.crop((prev, cur, nxt), x, y, sc)       # 3, 48, 48, 3 at the ball's scale
        g = X.astype(np.float32).mean(-1) / 255; sd = max(g[1].std(), 0.03)
        c = slice(21, 27); ring = np.ones((48, 48), bool); ring[14:34, 14:34] = False
        contrast = (g[1][c, c].mean() - np.median(g[1][ring])) / sd
        r = max(resid(X[1], X[0])[c, c].mean(), resid(X[1], X[2])[c, c].mean()) / sd
        d = max(np.abs(X[1].astype(np.float32) - X[0]).mean(-1)[c, c].mean(), np.abs(X[1].astype(np.float32) - X[2]).mean(-1)[c, c].mean()) / 255 / sd
        print('v%d frame %6d %-7s brightness against its surround %+5.1f   colour change %4.2f   any change %4.2f   ratio %.2f   score %.2f' % (v, f, what, contrast, r, d, r / max(d, 1e-6), row[3]))
        break
