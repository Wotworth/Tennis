"""Check set (round 2, 18 Nov): the detector over +-HALF frames around each check frame
(valset/frames.csv), cached in ml/valwin/{tag}_{i}.npy. Separate from the fixed test set: used to
set the tracker's thresholds and to pick candidate spots for labelling."""
import numpy as np, sys, os, csv, multiprocessing as mp, common

HALF = 30
VAL = f'{common.ROOT}/valset'   # frames.csv and labels.csv as in vision/testset/check


def frames():
    return [(int(r['i']), int(r['v']), int(r['frame'])) for r in csv.DictReader(open(f'{VAL}/frames.csv'))]


def one(a):
    i, v, fr, w, tag = a
    import detect_video as DV
    out = f'{common.ROOT}/ml/valwin/{tag}_{i:02d}.npy'
    if not os.path.exists(out): DV.main(v, fr - HALF, fr + HALF, 1, w, out)


if __name__ == '__main__':
    w, tag = sys.argv[1], sys.argv[2]
    os.makedirs(f'{common.ROOT}/ml/valwin', exist_ok=True)
    with mp.Pool(4) as p:
        p.map(one, [(i, v, fr, w, tag) for i, v, fr in frames()], chunksize=1)
    print('all done')
