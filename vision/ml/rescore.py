"""Every detector on the test set, first labels and reviewed labels."""
import numpy as np, csv, os, sys, importlib, common, tracker as T
def dets_baseline():
    d = {}
    for r in csv.DictReader(open(f'{common.ROOT}/ml/baseline.csv')):
        d.setdefault((int(r['v']), int(r['i'])), []).append((float(r['x']), float(r['y'])))
    return d
def dets_tracker(tag):
    d = {}
    for (v, i), lab in common.labels().items():
        D = np.load(f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy')
        Ds, out = T.chains(D[D[:, 3] > 0.05]); b = T.ball_per_frame(Ds, out)
        d[(v, i)] = [b[lab['frame']]] if lab['frame'] in b else []
    return d
def dets_classifier(tag, thr):
    d = {}
    for (v, i), lab in common.labels().items():
        D = np.load(f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy'); D = D[D[:, 0] == lab['frame']]
        d[(v, i)] = [(r[1], r[2]) for r in D[D[:, 3] > thr]]
    return d
tags = sys.argv[1:] or ['v3o']
for ts in ('original', 'reviewed'):
    os.environ['TESTSET'] = ts
    print('==== test set:', ts)
    common.show(common.score(dets_baseline()), 'old: colour + rules')
    for t in tags:
        common.show(common.score(dets_classifier(t, 0.9)), f'{t}: classifier > 0.9')
        common.show(common.score(dets_tracker(t)), f'{t}: tracker')
