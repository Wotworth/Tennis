"""The detector over every point of a SwingVision export (points from overlay.py's TAG_points.csv),
every STEP-th frame, a few points at a time. Rows as detect_video. Usage: detect_points.py V OVERLAY_DIR OUTDIR
(env WEIGHTS, PRE, STEP=2, WORKERS=3). Two frames are left off each end of a point: their
neighbours lie across the cut."""
import sys, os, csv, multiprocessing as mp


def one(a):
    v, i, first, last, step, weights, out = a
    if os.path.exists(out): return out
    import detect_video as DV
    DV.main(v, first, last, step, weights, out + '.tmp.npy'); os.replace(out + '.tmp.npy', out)
    return out


if __name__ == '__main__':
    v, ovl, outdir = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    os.makedirs(outdir, exist_ok=True)
    step = int(os.environ.get('STEP', 2)); w = os.environ['WEIGHTS']
    P = list(csv.DictReader(open(f'{ovl}/v{v}_points.csv')))
    # env USE (the 'use' column: train | test), FROM and UNTIL (frames) pick some of the points
    use = os.environ.get('USE'); lo = int(os.environ.get('FROM', 0)); hi = int(os.environ.get('UNTIL', 10 ** 9))
    P = [p for p in P if (not use or p.get('use', 'train') == use) and int(p['first']) >= lo and int(p['last']) < hi]
    jobs = [(v, int(p['point']), int(p['first']) + 4, int(p['last']) - 4, step, w, f'{outdir}/v{v}_p{int(p["point"]):03d}.npy') for p in P if int(p['last']) - int(p['first']) > 60]
    with mp.Pool(int(os.environ.get('WORKERS', 3))) as pool:
        for o in pool.imap_unordered(one, jobs, chunksize=1): print('point done', o, flush=True)
    print('all points done', flush=True)
