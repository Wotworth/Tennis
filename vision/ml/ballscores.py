"""For each labelled ball in play: the classifier's best score within 10 px at the test frame, and
its rank among that frame's proposals (from eval_windows' cache)."""
import numpy as np, sys, common
tag = sys.argv[1]
L = common.labels(); rows = []
for (v, i), lab in sorted(L.items()):
    D = np.load(f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy'); D = D[D[:, 0] == lab['frame']]
    for (x, y) in lab['balls']:
        d = np.hypot(D[:, 1] - x, D[:, 2] - y)
        if len(d) == 0 or d.min() > 10: rows.append((v, i, -1, -1, len(D))); continue
        s = D[d <= 10, 3].max(); rank = int((D[:, 3] > s).sum()) + 1
        rows.append((v, i, s, rank, len(D)))
for r in rows: print('v%d f%02d  score %.3f  rank %d of %d' % r)
s = np.array([r[2] for r in rows if r[2] >= 0])
print('proposed %d of %d; median score %.3f; rank 1 in %d' % (len(s), len(rows), np.median(s), sum(r[3] == 1 for r in rows)))
