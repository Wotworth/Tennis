"""How many hand-labelled balls are darker than what is behind them? (Chris, 19 Nov: the light/dark
swap is an artificial test.) For every labelled ball in play of the fixed test set and the check set:
the middle's brightness against its surround (mine5.features' contrast), the colour-change share,
and whether rounds 4 and 5 (tracker) have it."""
import numpy as np, csv, sys, common, proposals as P, gen_data as G, tracker as T, mine5
from detect_video import stream

def tracked(tag_file):
    D = np.load(tag_file); Ds, ch = T.chains(D[D[:, 3] > 0.05]); return D, T.ball_per_frame(Ds, ch)

rows = []
items = [('test', v, i, lab['frame'], lab['balls']) for (v, i), lab in sorted(common.labels().items())]
VAL = f'{common.ROOT}/valset'
F = {int(r['i']): (int(r['v']), int(r['frame'])) for r in csv.DictReader(open(f'{VAL}/frames.csv'))}
L = {}
for r in csv.DictReader(open(f'{VAL}/labels.csv')):
    if r['verdict'] == 'ball': L.setdefault(int(r['i']), []).append((float(r['x']), float(r['y'])))
items += [('check', F[i][0], i, F[i][1], b) for i, b in sorted(L.items())]
for kind, v, i, fr, balls in items:
    if not balls: continue
    f4 = f'{common.ROOT}/ml/win/r4_v{v}_i{i:02d}.npy' if kind == 'test' else f'{common.ROOT}/ml/valwin/r4s_{i:02d}.npy'
    f5 = f4.replace('r4s_', 'r5_').replace('r4_', 'r5_')
    D4, b4 = tracked(f4); D5, b5 = tracked(f5)
    imgs = list(stream(v, fr - P.K, 2 * P.K + 1)); cur = imgs[P.K]
    pa = P.moved(imgs[0], *P.shift(cur, imgs[0])); na = P.moved(imgs[-1], *P.shift(cur, imgs[-1]))
    R = D4[D4[:, 0] == fr]
    for (x, y) in balls:
        sc = 6.0
        if len(R):
            d = np.hypot(R[:, 1] - x, R[:, 2] - y); k = d.argmin()
            sc = G.scale_of(R[k, 6], R[k, 7], R[k, 8]) if d[k] <= 10 else float(np.median(0.5 * (R[:, 7] + R[:, 8])))
        X = G.crop((pa, cur, na), x, y, sc)[None]
        con, rat = mine5.features(X)
        hit = lambda b: fr in b and np.hypot(b[fr][0] - x, b[fr][1] - y) <= 10
        rows.append((kind, v, i, fr, x, y, float(con[0]), float(rat[0]), hit(b4), hit(b5)))
A = np.array([(r[6], r[7], r[8], r[9]) for r in rows])
print('labelled balls in play:', len(rows))
for name, m in (('darker than the surround (contrast < -0.2)', A[:, 0] < -0.2), ('about level (-0.2 to 0.2)', np.abs(A[:, 0]) <= 0.2), ('lighter (> 0.2)', A[:, 0] > 0.2)):
    print('  %-44s %2d   round 4 has %2d, round 5 has %2d' % (name, m.sum(), A[m, 2].sum(), A[m, 3].sum()))
for r in rows:
    if r[6] < 0.2: print('   %s v%d i%02d frame %d (%.0f, %.0f): contrast %.2f, colour-change share %.2f, r4 %d r5 %d' % (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]))
