"""Self-training input: the detector over stretches of each video well away from the test frames
(at least 600 frames, 10 s, from any of them). No labels are used."""
import numpy as np, sys, os, multiprocessing as mp, common

LEN = 240          # frames per stretch (4 s at 60 fps)
N = {1: 8, 2: 8, 3: 12}
AWAY = 600


def stretches(v, seed=11):
    rng = np.random.default_rng(seed + v)
    test = np.loadtxt(f'{common.ROOT}/testset/v{v}/frames.csv', delimiter=',', ndmin=2)[:, 1]
    n = len(common.pts(v)); out = []
    while len(out) < N[v]:
        a = int(rng.integers(100, n - LEN - 100))
        if np.min(np.abs(test - (a + LEN / 2))) < AWAY + LEN / 2: continue
        if any(abs(a - b) < 2 * LEN for b in out): continue
        out.append(a)
    return sorted(out)


def one(a):
    v, s, weights, out = a
    import detect_video as DV
    f = f'{out}/v{v}_{s:06d}.npy'
    if not os.path.exists(f): DV.main(v, s, s + LEN - 1, 1, weights, f)
    return f


if __name__ == '__main__':
    # weights: one file, or three comma-separated (per video: a model that never trained on that
    # video's negatives, so its real balls are found and kept out of the mined negatives)
    W = sys.argv[1].split(','); W = W * 3 if len(W) == 1 else W
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    jobs = [(v, s, W[v - 1], out) for v in (1, 2, 3) for s in stretches(v)]
    print(len(jobs), 'stretches', flush=True)
    with mp.Pool(4) as p:
        p.map(one, jobs, chunksize=1)
    print('all done')
