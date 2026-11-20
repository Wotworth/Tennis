"""Lens calibration from a checkerboard clip (TV-CAL-01), the Python twin of the PC's MATLAB step.

python lens_from_checkerboard.py CLIP_OR_URL OUT.json [--serial S] [--mode 4K240-Linear] [--start 0] [--seconds 90]

Chris, 21 Nov (home test a): one 90-second clip per camera and lens. Frames are read straight from
the file (or a link) by FFmpeg, about 6 a second, never stored. The board is 10 x 7 squares of 40 mm,
so 9 x 6 inner corners. About 60 sharp, well-spread views are kept (the picture is cut into a 4 x 3
grid and views are taken so every cell gets some, the board's tilt varying). Both lens models are
fitted, as TV-CAL-01 asks:
  standard: r = f * t * (1 + k1 t^2 + k2 t^4 + k3 t^6), t = tan(theta)    (OpenCV calibrateCamera)
  fisheye:  r = f * theta * (1 + k1 th^2 + k2 th^4 + k3 th^6 + k4 th^8)   (OpenCV fisheye)
each with its own centre (cx, cy) and pixel aspect; the one with the lower reprojection error is
kept (target 0.5 px), the standard one when they are within 2%. Tangential terms are not fitted: the pipeline's lens model is radial
(tv.lens.radius), and they are tiny on a GoPro.
OUT.json is read by tv.lens.fromCalibration (MATLAB): type calibStandard / calibFisheye, f (px),
centre offset from the picture's middle (px), aspect fy/fx, k, picture size, rms, views, coverage.
"""
import argparse, json, subprocess, sys
import numpy as np
import cv2

COLS, ROWS, SQ = 9, 6, 0.040            # inner corners, square size (m)


def frames(src, start, seconds, fps_out, width):
    """Frames from FFmpeg as grey images, scaled to `width` for finding the board."""
    probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                            'stream=width,height', '-of', 'json', src], capture_output=True, text=True, check=True)
    s = json.loads(probe.stdout)['streams'][0]
    W, H = s['width'], s['height']
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-t', str(seconds), '-i', src,
           '-vf', f'fps={fps_out},format=gray', '-f', 'rawvideo', '-']
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    n = W * H
    while True:
        b = p.stdout.read(n)
        if len(b) < n:
            break
        yield W, H, np.frombuffer(b, np.uint8).reshape(H, W)
    p.wait()


def find(img):
    ok, c = cv2.findChessboardCornersSB(img, (COLS, ROWS), flags=cv2.CALIB_CB_NORMALIZE_IMAGE | cv2.CALIB_CB_ACCURACY)
    return c.reshape(-1, 2) if ok else None


def sharpness(img, c):
    x0, y0 = np.floor(c.min(0)).astype(int)
    x1, y1 = np.ceil(c.max(0)).astype(int)
    roi = img[max(0, y0):y1, max(0, x0):x1]
    return cv2.Laplacian(roi, cv2.CV_64F).var() if roi.size else 0


def pick(views, W, H, n=60):
    """Well-spread views: each of a 4 x 3 grid of cells in turn gets the sharpest unused view whose
    board centre lies in it, then the rest by sharpness."""
    cells = {}
    for i, (c, s) in enumerate(views):
        m = c.mean(0)
        k = (min(3, int(4 * m[0] / W)), min(2, int(3 * m[1] / H)))
        cells.setdefault(k, []).append((s, i))
    for k in cells:
        cells[k].sort(reverse=True)
    out = []
    while len(out) < n and any(cells.values()):
        for k in list(cells):
            if cells[k] and len(out) < n:
                out.append(cells[k].pop(0)[1])
    return out, len(cells)


def calibrate(views, W, H):
    obj = np.zeros((COLS * ROWS, 3), np.float32)
    obj[:, :2] = np.mgrid[0:COLS, 0:ROWS].T.reshape(-1, 2) * SQ
    O = [obj] * len(views)
    I = [v.astype(np.float32) for v in views]
    res = {}
    # standard model: three radial terms, no tangential
    fl = cv2.CALIB_ZERO_TANGENT_DIST
    rms, K, d, _, _ = cv2.calibrateCamera(O, I, (W, H), None, None, flags=fl)
    res['calibStandard'] = dict(rms=rms, K=K, k=[d[0, 0], d[0, 1], d[0, 4]])
    # fisheye model
    try:
        O4 = [o.reshape(-1, 1, 3).astype(np.float64) for o in O]
        I4 = [i.reshape(-1, 1, 2).astype(np.float64) for i in I]
        Kf = np.zeros((3, 3));  df = np.zeros((4, 1))
        flf = cv2.fisheye.CALIB_RECOMPUTE_EXTRINSIC | cv2.fisheye.CALIB_FIX_SKEW
        rmsf, Kf, df, _, _ = cv2.fisheye.calibrate(O4, I4, (W, H), Kf, df, flags=flf,
                                                  criteria=(cv2.TERM_CRITERIA_COUNT + cv2.TERM_CRITERIA_EPS, 200, 1e-9))
        res['calibFisheye'] = dict(rms=rmsf, K=Kf, k=list(df.ravel()))
    except cv2.error as e:
        print('fisheye fit failed:', e, file=sys.stderr)
    return res


def to_json(name, r, W, H, n, cells, serial, mode):
    K = r['K']
    return dict(type=name, serial=serial, mode=mode, widthPx=W, heightPx=H, f=float(K[0, 0]),
                aspect=float(K[1, 1] / K[0, 0]), cx=float(K[0, 2] - (W - 1) / 2), cy=float(K[1, 2] - (H - 1) / 2),
                k=[float(v) for v in r['k']], rmsPx=float(r['rms']), views=n, gridCells=cells,
                note='cx, cy: centre offset from the middle of the picture, px; OpenCV conventions (0-based pixels)')


def main():
    a = argparse.ArgumentParser()
    a.add_argument('src');  a.add_argument('out')
    a.add_argument('--serial', default='');  a.add_argument('--mode', default='')
    a.add_argument('--start', type=float, default=0);  a.add_argument('--seconds', type=float, default=90)
    a.add_argument('--fps', type=float, default=6)
    o = a.parse_args()
    views, W, H = [], None, None
    for W, H, img in frames(o.src, o.start, o.seconds, o.fps, None):
        small = cv2.resize(img, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
        c = find(small)
        if c is None:
            continue
        c = c * 2.0                                  # back to full size, then refine there
        c = cv2.cornerSubPix(img, c.astype(np.float32).reshape(-1, 1, 2), (7, 7), (-1, -1),
                             (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.01)).reshape(-1, 2)
        views.append((c, sharpness(img, c)))
    print(f'board found in {len(views)} frames')
    if len(views) < 15:
        sys.exit('too few views with the whole board: record again, slower, with the board in more of the picture')
    idx, cells = pick(views, W, H)
    res = calibrate([views[i][0] for i in idx], W, H)
    best = min(res, key=lambda k: res[k]['rms'])
    if best != 'calibStandard' and res[best]['rms'] > 0.98 * res['calibStandard']['rms']:
        best = 'calibStandard'                       # a tie: the standard model (it suits Linear and extrapolates better)
    for k, r in res.items():
        print(f"{k}: {r['rms']:.3f} px")
    out = to_json(best, res[best], W, H, len(idx), cells, o.serial, o.mode)
    out['other'] = {k: dict(rmsPx=float(r['rms'])) for k, r in res.items() if k != best}
    json.dump(out, open(o.out, 'w'), indent=1)
    print(f'kept {best}: {out["rmsPx"]:.3f} px over {len(idx)} views in {cells} of 12 picture cells -> {o.out}')


if __name__ == '__main__':
    main()
