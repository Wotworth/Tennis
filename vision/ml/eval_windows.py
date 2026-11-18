"""Test set, with time: the detector over +-HALF frames around each test frame, then the tracker.
Scores (same rules as the baseline): the classifier alone per frame at several thresholds, and the
tracker's one ball in play."""
import numpy as np, sys, os, multiprocessing as mp, common, tracker as T

HALF = 30


def one(args):
    v, i, frame, weights, tag = args
    import detect_video as DV
    out = f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy'
    if not os.path.exists(out):
        DV.main(v, frame - HALF, frame + HALF, 1, weights, out)
    return out


def main(weights, tag):
    os.makedirs(f'{common.ROOT}/ml/win', exist_ok=True)
    L = common.labels()
    jobs = [(v, i, lab['frame'], weights, tag) for (v, i), lab in sorted(L.items())]
    with mp.Pool(4) as p:
        p.map(one, jobs, chunksize=1)
    per = {}
    for (v, i), lab in L.items():
        D = np.load(f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy')
        per[(v, i)] = (lab['frame'], D)
    for thr in (0.5, 0.9, 0.98):
        d = {k: [(r[1], r[2]) for r in D[(D[:, 0] == fr) & (D[:, 3] > thr)]] for k, (fr, D) in per.items()}
        common.show(common.score(d), 'classifier > %.2f' % thr)
        print()
    d = {}
    for k, (fr, D) in per.items():
        Ds, out = T.chains(D[D[:, 3] > 0.05])
        b = T.ball_per_frame(Ds, out)
        d[k] = [b[fr]] if fr in b else []
    common.show(common.score(d), 'tracker: one ball in play')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
