"""Shared helpers for the ball-detection experiments (private footage only; nothing here is committed
with data). Frames are read exactly as MATLAB's tv.media.readFrames does (accurate seek by pts)."""
import os, subprocess, numpy as np, csv, os

ROOT = '/home/user/private-footage'
VIDEO = {1: f'{ROOT}/video.bin', 2: f'{ROOT}/video2.bin', 3: f'{ROOT}/v3/video3_mid.mp4'}
W, H, FPS = 1920, 1080, 60.0
OVERLAYS = {1: [(1630, 10, 1915, 470), (1430, 925, 1915, 1070)], 2: [(1630, 10, 1915, 470), (1430, 925, 1915, 1070)], 3: []}


def pts(v):
    return np.fromfile(f'{ROOT}/ml/pts_v{v}.f64', dtype=np.float64)


_PTS = {}


def read(v, first, count):
    """Frames first..first+count-1 (0-based) as (n, H, W, 3) uint8."""
    p = _PTS.setdefault(v, pts(v))
    t = p[first] - 0.25 / FPS
    cmd = ['ffmpeg', '-v', 'error', '-ss', '%.6f' % t, '-i', VIDEO[v], '-frames:v', str(count), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    raw = subprocess.run(cmd, stdout=subprocess.PIPE, check=True).stdout
    n = len(raw) // (W * H * 3)
    return np.frombuffer(raw[:n * W * H * 3], np.uint8).reshape(n, H, W, 3)


def geom(v):
    """(dmin, dmax): the ball's diameter range in px at each pixel (half resolution; 0 = not in the court of interest)."""
    a = np.fromfile(f'{ROOT}/ml/geom_v{v}.f32', dtype=np.float32)
    h, w = int(a[0]), int(a[1])
    dmin = a[2:2 + h * w].reshape(h, w)
    dmax = a[2 + h * w:2 + 2 * h * w].reshape(h, w)
    return dmin, dmax


def labels():
    """Test set: per (v, i): frame, in-play balls [(x, y)], ignore points [(x, y)] (still, held or unsure)."""
    frames = {}
    for v in (1, 2, 3):
        for row in csv.reader(open(f'{ROOT}/testset/v{v}/frames.csv')):
            i, fr, du, dv = map(int, row)
            frames[(v, i)] = {'frame': fr, 'shift': (du, dv), 'balls': [], 'ignore': []}
    for r in csv.DictReader(open(f'{ROOT}/testset/labels_moving.csv')):
        k = (int(r['v']), int(r['i']))
        p = (int(r['x']), int(r['y']))
        (frames[k]['balls'] if float(r['diff']) >= 20 else frames[k]['ignore']).append(p)
    # second look (18 Nov): every spot either detector put where no label was, checked blind on
    # five frames around it; moving balls the first labels missed are added, unsure ones ignored
    if os.environ.get('TESTSET', 'reviewed') == 'reviewed':
        for r in csv.DictReader(open(f'{ROOT}/testset/labels_review.csv')):
            k = (int(r['v']), int(r['i'])); p = (float(r['x']), float(r['y']))
            if r['verdict'] == 'ball': frames[k]['balls'].append(p)
            elif r['verdict'] == 'unsure': frames[k]['ignore'].append(p)
    return frames


def score(dets, radius=10):
    """dets: {(v, i): [(x, y), ...]} in raw frame pixels. Returns per-video and total counts."""
    L = labels()
    out = {}
    for (v, i), lab in L.items():
        d = dets.get((v, i), [])
        s = out.setdefault(v, {'balls': 0, 'found': 0, 'false': 0, 'frames': 0})
        s['frames'] += 1
        s['balls'] += len(lab['balls'])
        used = set()
        for b in lab['balls']:
            hit = [j for j, p in enumerate(d) if j not in used and np.hypot(p[0] - b[0], p[1] - b[1]) <= radius]
            if hit:
                s['found'] += 1; used.add(hit[0])
        for j, p in enumerate(d):
            if j in used: continue
            if any(np.hypot(p[0] - q[0], p[1] - q[1]) <= radius for q in lab['ignore'] + lab['balls']): continue
            s['false'] += 1
    t = {k: sum(o[k] for o in out.values()) for k in ('balls', 'found', 'false', 'frames')}
    out['all'] = t
    return out


def show(sc, name):
    for k in (1, 2, 3, 'all'):
        s = sc[k]
        print('%-28s %-4s found %2d of %2d balls in play; %3d false spots in %d frames' % (name, k, s['found'], s['balls'], s['false'], s['frames']))
