"""How late is SwingVision's bounce dot, and does it land where the tracked ball turned?
For each dot inside a stretch the detector has already been run on (private footage), the tracked
ball's sharpest upward turns in the 2 s before the dot are the candidate real bounces; the one
nearest the dot's court position (through the fitted camera) is taken. Run with PYTHONPATH=ml."""
import sys, glob, csv, numpy as np
import common, physics, tracker

def ground(cam, u, v):
    d = cam.ray(u, v); s = -cam.pos[2] / d[2]; return cam.pos + s * d

def turns(ball, k=3):
    """[(frame, u, v, strength)]: frames where the ball's downward speed in the picture drops sharply."""
    out = []
    for f in sorted(ball):
        if f - k in ball and f + k in ball:
            a = (np.array(ball[f + k]) - 2 * np.array(ball[f]) + np.array(ball[f - k])) / k ** 2
            out.append((f, ball[f][0], ball[f][1], -a[1], np.hypot(*a)))
    return out

rows = []
for v in (1, 2):
    cam = physics.Camera(v)
    B = [b for b in csv.DictReader(open(f'../ovl/v{v}_bounces.csv'))]
    for path in sorted(glob.glob(f'{common.ROOT}/ml/mine*/v{v}_*.npy')):
        D = np.load(path); D = D[D[:, 3] > 0.3]
        if len(D) == 0: continue
        f0, f1 = int(D[:, 0].min()), int(D[:, 0].max())
        mine = [b for b in B if f0 + 30 <= int(b['frame']) <= f1 - 10 and b['mark'] != 'net']
        if not mine: continue
        D, ch = tracker.chains(D); ball = tracker.ball_per_frame(D, ch); T = turns(ball)
        for b in mine:
            fb = int(b['frame']); P = np.array([float(b['xM']), float(b['yM'])])
            cand = [t for t in T if abs(t[0] - fb) <= 60 and t[3] > 0.25]
            d = [np.hypot(*(ground(cam, t[1], t[2])[:2] - P)) for t in cand]
            i = int(np.argmin(d)) if cand else -1
            rows.append((v, fb, b['mark'], P[0], P[1], len(cand), (fb - cand[i][0], d[i]) if cand else None))
ok = [r for r in rows if r[6] and r[6][1] < 1]
dt = np.array([r[6][0] for r in ok]); d = np.array([r[6][1] for r in ok])
print(len(rows), 'bounce marks inside tracked stretches;', len(ok), 'have a tracked upward turn within 1 m and 1 s')
print('dot appears %+.0f frames from the turn (median); 10th-90th percentile %+.0f to %+.0f; extremes %+d, %+d' % (np.median(dt), *np.percentile(dt, [10, 90]), dt.min(), dt.max()))
print('distance: median %.2f m, 90%% within %.2f m' % (np.median(d), np.percentile(d, 90)))
for v in (1, 2): print('video', v, sorted(r[6][0] for r in ok if r[0] == v))
print('not matched:', [(r[0], r[1], r[2], round(r[3], 1), r[6] and (r[6][0], round(r[6][1], 1))) for r in rows if r not in ok])
print('video 2 (frame, offset):', sorted((r[1], r[6][0]) for r in ok if r[0] == 2))
