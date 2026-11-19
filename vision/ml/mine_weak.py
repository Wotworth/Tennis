"""Weak labels from SwingVision's bounce marks (overlay.py), for self-training; never for the test set.
A mark says: about here on the court, about now, a ball bounced (SwingVision's own estimate). Around
each mark the detector's proposals are searched for the ball it should belong to:
  1. the tracker's ball in play, if it passes within 1 m of the mark (on the ground, through the
     fitted camera) within 0.2 s: its points near the mark are ball examples (most are found this way
     and add little: the classifier already scores them);
  2. otherwise, any smooth path among ALL proposals near the mark, whatever the classifier scored
     them: the chain search is run on the proposals within NEAR_PX and a third of a second of the
     mark with every score lifted to at least LIFT, and a chain counts only if it passes the mark
     within its uncertainty and moves like a ball (mine2.smooth_points). Its points are the hard ball
     examples the classifier missed.
The guard stays: nothing on or near these paths may become a "not a ball" example.
Usage: mine_weak.py V OVERLAY_DIR DETECTIONS_DIR OUT.npz   (dry run prints counts; rows saved for the crop pass)"""
import sys, csv, os, numpy as np
import common, physics, tracker, mine2

FPS, NEAR_PX, LIFT, WIN = 60.0, 250.0, 0.62, 20


def ground(cam, u, v):
    d = cam.ray(u, v); s = -cam.pos[2] / d[2]; return (cam.pos + s * d)[:2]


def main(v, ovl, det, out):
    cam = physics.Camera(v)
    P = list(csv.DictReader(open(f'{ovl}/v{v}_points.csv'))); B = list(csv.DictReader(open(f'{ovl}/v{v}_bounces.csv')))
    n = dict(marks=0, tracked=0, found=0, none=0, hard=0, easy=0); keep = []
    for p in P:
        i = int(p['point']); path = f'{det}/v{v}_p{i:03d}.npy'
        if not os.path.exists(path): continue
        Dall = np.load(path); D = Dall[Dall[:, 3] > 0.05]
        Ds, ch = tracker.chains(D) if len(D) else (D, [])
        ball = tracker.ball_per_frame(Ds, ch)
        rows_of = {}
        for value, pth in ch:
            for j in pth: rows_of[(int(Ds[j, 0]), round(float(Ds[j, 1]), 1))] = Ds[j]
        for b in B:
            if int(b['point']) != i or b['mark'] == 'net': continue
            fb = int(b['frame']); g = np.array([float(b['xM']), float(b['yM'])]); n['marks'] += 1
            d = {f: np.hypot(*(ground(cam, *ball[f]) - g)) for f in range(fb - 12, fb + 13) if f in ball}
            if d and min(d.values()) < 1.0:
                n['tracked'] += 1
                pts = [rows_of.get((f, round(float(ball[f][0]), 1))) for f in range(fb - WIN, fb + WIN + 1) if f in ball]
                pts = [r for r in pts if r is not None]
                n['easy'] += len(pts); keep += [np.r_[r, v, i, fb, 0] for r in pts]
                continue
            q, _ = cam.project(np.array([[g[0], g[1], 0.033], [g[0], g[1] + 1.0, 0.033], [g[0] + 1.0, g[1], 0.033]]))
            rad = max(15.0, np.hypot(*(q[1] - q[0])), np.hypot(*(q[2] - q[0])))
            L = Dall[(np.abs(Dall[:, 0] - fb) <= WIN) & (np.hypot(Dall[:, 1] - q[0, 0], Dall[:, 2] - q[0, 1]) <= NEAR_PX)].copy()
            best = None
            if len(L) >= 8:
                L[:, 3] = np.maximum(L[:, 3], LIFT)
                Ls, lch = tracker.chains(L)
                for value, pth in lch:
                    R = Ls[pth]
                    close = (np.abs(R[:, 0] - fb) <= 6) & (np.hypot(R[:, 1] - q[0, 0], R[:, 2] - q[0, 1]) <= rad)
                    if len(R) < 8 or not close.any(): continue
                    good = mine2.smooth_points(R) & ~mine2.slow_points(R)
                    if good.sum() >= 8 and (best is None or good.sum() > best[0]): best = (int(good.sum()), R[good])
            if best is None: n['none'] += 1; continue
            n['found'] += 1
            # the classifier's own scores for those points (the lift was only for the search)
            orig = {(int(r[0]), round(float(r[1]), 1), round(float(r[2]), 1)): r[3] for r in Dall[np.abs(Dall[:, 0] - fb) <= WIN]}
            for r in best[1]:
                r = r.copy(); r[3] = orig.get((int(r[0]), round(float(r[1]), 1), round(float(r[2]), 1)), r[3])
                n['hard'] += r[3] < 0.5; keep.append(np.r_[r, v, i, fb, 1])
    K = np.array(keep) if keep else np.zeros((0, 15))
    np.savez_compressed(out, rows=K.astype(np.float32))
    print(f"video {v}: {n['marks']} bounce marks; the tracker's ball passes {n['tracked']}; a smooth path among all proposals passes {n['found']} more; nothing at {n['none']}")
    print(f"  ball examples: {n['easy']} on tracked paths, {len(K) - n['easy']} on the recovered paths, of which the classifier scored {n['hard']} under 0.5")


if __name__ == '__main__':
    main(int(sys.argv[1]), *sys.argv[2:5])
