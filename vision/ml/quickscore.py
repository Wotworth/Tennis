"""The classifier alone at each test frame (no tracking): writes win/{tag}_v{v}_i{i}.npy with that
frame's rows only, for ballscores.py. Use a tag ending in q so eval_windows never reads it."""
import numpy as np, sys, os, multiprocessing as mp, common


def one(a):
    v, i, fr, w, tag = a
    import detect_video as DV
    out = f'{common.ROOT}/ml/win/{tag}_v{v}_i{i:02d}.npy'
    if not os.path.exists(out): DV.main(v, fr, fr, 1, w, out)


if __name__ == '__main__':
    w, tag = sys.argv[1], sys.argv[2]
    jobs = [(v, i, lab['frame'], w, tag) for (v, i), lab in sorted(common.labels().items())]
    with mp.Pool(int(os.environ.get('NPROC', 4))) as p: p.map(one, jobs, chunksize=1)
