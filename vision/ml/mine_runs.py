"""Self-training input: the detector over stretches of each video well away from the test frames
(at least 600 frames, 10 s, from any of them). No labels are used."""
import numpy as np, sys, os, multiprocessing as mp, common

LEN = 240          # frames per stretch (4 s at 60 fps)
N = {1: 8, 2: 8, 3: 12}
MID = (128091, 182091)   # the whole clay recording's frames for 36:00-51:00 (the cut the test frames come from)
AWAY = 600


def stretches(v, seed=11, n=None, avoid=(), away=AWAY):
    """Stretch starts in video v, at least AWAY frames from every test frame (and from the test
    cut of the clay recording, for v 4) and two stretches' length from `avoid` and each other."""
    rng = np.random.default_rng(seed + v)
    if v == 4: test = np.array(MID, float)
    else: test = np.loadtxt(f'/home/user/tennis/vision/testset/frames_v{v}.csv', delimiter=',', skiprows=1, ndmin=2)[:, 1]
    total = len(common.pts(v)); out = []; n = n or N[v]
    while len(out) < n:
        a = int(rng.integers(100, total - LEN - 100))
        mid = a + LEN / 2
        if v == 4 and MID[0] - away - LEN <= a <= MID[1] + away: continue
        if v != 4 and np.min(np.abs(test - mid)) < away + LEN / 2: continue
        if any(abs(a - b) < 2 * LEN for b in list(out) + list(avoid)): continue
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
    W = sys.argv[1].split(','); W = W * 4 if len(W) == 1 else W
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    if os.environ.get('ROUND') == '2':
        # round 2 (18 Nov): 24 stretches of the whole clay recording outside its test cut, 8 more of
        # each other video away from round 1's (4 s from any test frame: the short videos have no room for 10 s)
        jobs = [(4, s, W[3], out) for s in stretches(4, seed=21, n=24)]
        jobs += [(v, s, W[v - 1], out) for v in (1, 2) for s in stretches(v, seed=31, n=8, avoid=stretches(v), away=240)]
    else:
        jobs = [(v, s, W[v - 1], out) for v in (1, 2, 3) for s in stretches(v)]
    print(len(jobs), 'stretches', flush=True)
    with mp.Pool(4) as p:
        p.map(one, jobs, chunksize=1)
    print('all done')
