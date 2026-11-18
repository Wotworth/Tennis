"""The Python twin of the learned detector over every clip of a video: clip_NNN.csv per clip
(columns as runSingle's detectLearned reads them)."""
import numpy as np, sys, os, multiprocessing as mp, common


def one(a):
    v, r, f0, f1, weights, out = a
    import detect_video as DV
    f = f'{out}/clip_{r:03d}.csv'
    if os.path.exists(f): return
    tmp = f'{out}/clip_{r:03d}.npy'
    DV.main(v, f0, f1, 1, weights, tmp)
    R = np.load(tmp)
    np.savetxt(f, R, delimiter=',', fmt='%.4f', header='frame,x,y,score,area,length,width,dmin,dmax,du,dv', comments='')
    os.remove(tmp)


if __name__ == '__main__':
    v, weights, out = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    nmax = int(sys.argv[4]) if len(sys.argv) > 4 else 10 ** 6
    os.makedirs(out, exist_ok=True)
    C = np.loadtxt(f'{common.ROOT}/ml/clips_v{v}.csv', delimiter=',', ndmin=2).astype(int)[:nmax]
    jobs = [(v, r + 1, max(c[0], 2), min(c[1], len(common.pts(v)) - 3), weights, out) for r, c in enumerate(C)]
    with mp.Pool(4) as p:
        p.map(one, jobs, chunksize=1)
    print('all done')
