"""Check-set scores (round 2): tracker (one ball in play) with given chain settings, per source.
Found: the tracked point within 10 px of a labelled ball; false: not near a ball or an unsure spot."""
import numpy as np, csv, sys, common, tracker as T
VAL = f'{common.ROOT}/valset'   # frames.csv and labels.csv as in vision/testset/check
F = [(int(r['i']), int(r['v']), int(r['frame'])) for r in csv.DictReader(open(f'{VAL}/frames.csv'))]
LAB = {}
for r in csv.DictReader(open(f'{VAL}/labels.csv')):
    LAB.setdefault(int(r['i']), []).append((float(r['x']), float(r['y']), r['verdict']))


def score(tag, cut=0.05, **kw):
    old = {k: getattr(T, k) for k in kw}
    for k, val in kw.items(): setattr(T, k, val)
    out = {}
    try:
        for i, v, fr in F:
            D = np.load(f'{common.ROOT}/ml/valwin/{tag}_{i:02d}.npy')
            Ds, ch = T.chains(D[D[:, 3] > cut]); b = T.ball_per_frame(Ds, ch)
            g = 'clay' if v == 4 else 'v%d' % v
            s = out.setdefault(g, [0, 0, 0])
            L = LAB.get(i, []); balls = [(x, y) for x, y, d in L if d == 'ball']; s[0] += len(balls)
            if fr in b:
                x, y = b[fr]
                if any(np.hypot(x - a, y - c) <= 10 for a, c in balls): s[1] += 1
                elif not any(np.hypot(x - a, y - c) <= 10 for a, c, d in L if d != 'not'): s[2] += 1
    finally:
        for k, val in old.items(): setattr(T, k, val)
    tot = [sum(s[j] for s in out.values()) for j in range(3)]
    out['all'] = tot
    return out


def show(o, name):
    print('%-34s' % name + '  '.join('%s %d/%d f%d' % (g, s[1], s[0], s[2]) for g, s in sorted(o.items())))


if __name__ == '__main__':
    for tag in sys.argv[1:]:
        show(score(tag), tag + ' default')
