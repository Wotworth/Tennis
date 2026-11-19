"""Shared helpers for the ball-detection experiments (private footage only; nothing here is committed
with data). Frames are read exactly as MATLAB's tv.media.readFrames does (accurate seek by pts)."""
import os, subprocess, numpy as np, csv

ROOT = '/home/user/private-footage'
VIDEO = {1: f'{ROOT}/video.bin', 2: f'{ROOT}/video2.bin', 3: f'{ROOT}/v3/video3_mid.mp4', 4: f'{ROOT}/v3/video3.bin',
         5: f'{ROOT}/s5/gopro7.mp4', 6: f'{ROOT}/s6/clip6.mp4', 7: f'{ROOT}/s7/clip7a.mp4'}   # 4: the whole clay recording (3 is its 36:00-51:00 cut)
# frame size: 1920 x 1080 unless the run says otherwise (env VIDEO_W, VIDEO_H; video 5 is a GoPro at 2704 x 2028)
W, H, FPS = int(os.environ.get('VIDEO_W', 1920)), int(os.environ.get('VIDEO_H', 1080)), 60.0
OVERLAYS = {1: [(1630, 10, 1915, 470), (1430, 925, 1915, 1070)], 2: [(1630, 10, 1915, 470), (1430, 925, 1915, 1070)], 3: [], 4: [], 5: [], 6: [], 7: [(1630, 10, 1915, 470), (1430, 925, 1915, 1070)]}


COND = os.environ.get('COND', 'plain')   # stress conditions: the same footage as another camera, light or ball colour would show it


def condition(F):
    """Frames (..., H, W, 3) uint8 under the stress condition COND (plain: unchanged).
    grey: no colour at all. hue: channels rotated (a yellow ball turns pink-blue, clothes change
    colour). dark: 40% of the light. invert: light and dark swapped, colour kept (a dark ball on a pale court). cool: a blue cast.
    warm: a strong orange cast with less contrast."""
    if COND == 'plain': return F
    f = F.astype(np.float32)
    if COND == 'grey': f = np.repeat(f.mean(axis=-1, keepdims=True), 3, axis=-1)
    elif COND == 'hue': f = f[..., [2, 0, 1]]
    elif COND == 'dark': f = f * 0.4
    elif COND == 'invert': f = f + (255 - 2 * f.mean(axis=-1, keepdims=True))      # brightness swapped, colour kept
    elif COND == 'cool': f = (f - 128) * 0.8 + 128; f = f * np.array([0.75, 0.95, 1.15], np.float32)
    elif COND == 'warm': f = (f - 128) * 0.7 + 128; f = f * np.array([1.15, 0.95, 0.6], np.float32)
    else: raise ValueError(COND)
    return np.clip(f, 0, 255).astype(np.uint8)


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
    return condition(np.frombuffer(raw[:n * W * H * 3], np.uint8).reshape(n, H, W, 3))


def geom(v):
    """(dmin, dmax): the ball's diameter range in px at each pixel (half resolution; 0 = not in the court of interest)."""
    a = np.fromfile(f'{ROOT}/ml/geom_v{v}.f32', dtype=np.float32)
    h, w = int(a[0]), int(a[1])
    dmin = a[2:2 + h * w].reshape(h, w)
    dmax = a[2 + h * w:2 + 2 * h * w].reshape(h, w)
    return dmin, dmax


TESTSET = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'testset')   # vision/testset (numbers only)


def labels():
    """Test set: per (v, i): frame, in-play balls [(x, y)], ignore points [(x, y)] (still, held or unsure)."""
    frames = {}
    for v in (1, 2, 3):
        for row in list(csv.reader(open(f'{TESTSET}/frames_v{v}.csv')))[1:]:
            i, fr, du, dv = map(int, row)
            frames[(v, i)] = {'frame': fr, 'shift': (du, dv), 'balls': [], 'ignore': []}
    for r in csv.DictReader(open(f'{TESTSET}/labels_moving.csv')):
        k = (int(r['v']), int(r['i']))
        p = (int(r['x']), int(r['y']))
        (frames[k]['balls'] if float(r['diff']) >= 20 else frames[k]['ignore']).append(p)
    # second look (18 Nov): every spot either detector put where no label was, checked blind on
    # five frames around it; moving balls the first labels missed are added, unsure ones ignored
    if os.environ.get('TESTSET', 'reviewed') == 'reviewed':
        for r in csv.DictReader(open(f'{TESTSET}/labels_review.csv')):
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
