"""SwingVision bounce marks the tracker's ball passes (within 1 m on the ground, within 12 frames):
the first test of mine_weak.py, alone, for several detection folders on the same marks.
Usage: markhits.py V OVERLAY_DIR DET_DIR [DET_DIR ...]"""
import sys, os, csv, numpy as np, common, physics, tracker
from mine_weak import ground
v = int(sys.argv[1]); ovl = sys.argv[2]; dirs = sys.argv[3:]
cam = physics.Camera(v)
P = list(csv.DictReader(open(f'{ovl}/v{v}_points.csv'))); B = list(csv.DictReader(open(f'{ovl}/v{v}_bounces.csv')))
pts = [int(p['point']) for p in P if all(os.path.exists(f'{d}/v{v}_p{int(p["point"]):03d}.npy') for d in dirs)]
res = {d: {} for d in dirs}; frames = {d: [0, 0] for d in dirs}
for d in dirs:
    for i in pts:
        Dall = np.load(f'{d}/v{v}_p{i:03d}.npy'); D = Dall[Dall[:, 3] > 0.05]
        Ds, ch = tracker.chains(D) if len(D) else (D, [])
        ball = tracker.ball_per_frame(Ds, ch)
        p = next(q for q in P if int(q['point']) == i); frames[d][0] += int(p['last']) - int(p['first']) + 1; frames[d][1] += len(ball)
        for k, b in enumerate(B):
            if int(b['point']) != i or b['mark'] == 'net': continue
            fb = int(b['frame']); g = np.array([float(b['xM']), float(b['yM'])])
            dd = [np.hypot(*(ground(cam, *ball[f]) - g)) for f in range(fb - 12, fb + 13) if f in ball]
            res[d][k] = bool(dd) and min(dd) < 1.0
keys = sorted(res[dirs[0]])
print(len(pts), 'points,', len(keys), 'bounce marks (in and out, not net)')
for d in dirs:
    print('  %-60s ball at %d of %d marks; ball tracked in %d of %d frames' % (d[-40:], sum(res[d][k] for k in keys), len(keys), frames[d][1], frames[d][0]))
if len(dirs) == 2:
    a, b = dirs; print('  both %d, only the first %d, only the second %d, neither %d' % (sum(res[a][k] and res[b][k] for k in keys), sum(res[a][k] and not res[b][k] for k in keys), sum(res[b][k] and not res[a][k] for k in keys), sum(not res[a][k] and not res[b][k] for k in keys)))
    # the near and far ends separately (x > 0 is the far end from the camera)
    for name, sel in (('near half', lambda k: float(B[k]['xM']) < 0), ('far half', lambda k: float(B[k]['xM']) >= 0)):
        ks = [k for k in keys if sel(k)]; print('  %s: %d marks; first %d, second %d' % (name, len(ks), sum(res[a][k] for k in ks), sum(res[b][k] for k in ks)))
