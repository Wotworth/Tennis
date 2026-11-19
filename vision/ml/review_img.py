"""Pictures for the private review document (frames stay out of the repository)."""
import sys, os, glob, csv, numpy as np
from PIL import Image, ImageDraw, ImageFont
import common, tracker

FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
SMALL = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)


def court_model():
    """Points along the court's lines and the net tape (m), as tv.calib.modelPoints."""
    hl, hd, hs, sv = 11.885, 5.485, 4.115, 6.40
    L = [(-hl, -hd, hl, -hd), (-hl, hd, hl, hd), (-hl, -hs, hl, -hs), (-hl, hs, hl, hs), (-hl, -hd, -hl, hd), (hl, -hd, hl, hd),
         (-sv, -hs, -sv, hs), (sv, -hs, sv, hs), (-sv, 0, sv, 0)]
    P = []
    for x0, y0, x1, y1 in L:
        n = int(np.hypot(x1 - x0, y1 - y0) / 0.03) + 2
        P.append(np.stack([np.linspace(x0, x1, n), np.linspace(y0, y1, n), np.zeros(n)], 1))
    n = 400; y = np.linspace(-hd - 0.914, hd + 0.914, n)
    P.append(np.stack([np.zeros(n), y, 0.914 + (1.07 - 0.914) * np.abs(y) / (hd + 0.914)], 1))      # the net tape
    return np.concatenate(P)


def lines_picture(v, out, width=1280):
    """The empty court (the median of 61 frames), the line pixels found (cyan) and, where a camera
    was fitted, the court's lines through it (magenta)."""
    bg = np.asarray(Image.open(f'{common.ROOT}/run{v}/bg.png').convert('RGB')).copy()
    m = np.asarray(Image.open(f'{common.ROOT}/run{v}/lines.png').convert('L')) > 0
    from scipy import ndimage
    bg[ndimage.binary_dilation(m, iterations=1)] = (0, 255, 255)
    a = bg.copy()
    if os.path.exists(f'{common.ROOT}/ml/cam_v{v}.f64'):
        import physics
        cam = physics.Camera(v); q, ok = cam.project(court_model()); q = np.round(q[ok]).astype(int)
        k = (q[:, 0] > 1) & (q[:, 0] < bg.shape[1] - 2) & (q[:, 1] > 1) & (q[:, 1] < bg.shape[0] - 2); q = q[k]
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1): a[q[:, 1] + dy, q[:, 0] + dx] = (255, 0, 255)
    im = Image.fromarray(np.concatenate([bg, a], axis=1)); s = 2 * width / im.size[0]
    im.resize((2 * width, int(im.size[1] * s)), Image.LANCZOS).save(out, quality=88)


def in_play(files):
    """The ball in play per frame over these detection files: {frame: (x, y, chain value)}."""
    ball = {}
    for f in files:
        D = np.load(f); D = D[D[:, 3] > 0.05]
        if not len(D): continue
        Ds, ch = tracker.chains(D); best = {}
        for value, p in ch:
            for i in p:
                fr = int(Ds[i, 0])
                if fr not in best or best[fr][2] < value: best[fr] = (Ds[i, 1], Ds[i, 2], value)
        ball.update(best)
    return ball


def path_picture(v, ball, a, b, out, title, width=1280, crop=None):
    """One frame (the middle of frames a..b) with the tracked ball's path over that stretch drawn on
    it: early points yellow, late points red, a ring at the ball in the frame shown."""
    mid = (a + b) // 2
    F = common.read(v, mid, 1)[0]
    im = Image.fromarray(F); d = ImageDraw.Draw(im)
    pts = [(f, ball[f][0], ball[f][1]) for f in range(a, b + 1) if f in ball]
    for (f0, x0, y0), (f1, x1, y1) in zip(pts[:-1], pts[1:]):
        t = (f0 - a) / max(b - a, 1); col = (255, int(255 * (1 - t)), 0)
        if f1 - f0 <= 8 and np.hypot(x1 - x0, y1 - y0) < 0.12 * common.W: d.line((x0, y0, x1, y1), fill=col, width=max(2, common.W // 640))
    r = max(4, common.W // 320)
    for f, x, y in pts: d.ellipse((x - r / 2, y - r / 2, x + r / 2, y + r / 2), fill=(255, int(255 * (1 - (f - a) / max(b - a, 1))), 0))
    if mid in ball:
        x, y = ball[mid][:2]; R = common.W // 60; d.ellipse((x - R, y - R, x + R, y + R), outline=(255, 0, 255), width=max(2, common.W // 640))
    if crop: im = im.crop(crop)
    s = width / im.size[0]; im = im.resize((width, int(im.size[1] * s)), Image.LANCZOS)
    d = ImageDraw.Draw(im); d.rectangle((0, 0, width, 30), fill=(0, 0, 0)); d.text((8, 4), title, font=FONT, fill=(255, 255, 255))
    im.save(out, quality=85)
    return len(pts)


def strip(v, f, x, y, out, title, S=128, Z=2, offs=(-6, -3, 0, 3, 6)):
    """Five crops around frame f centred on (x, y), the spot ringed in the middle one."""
    F = common.read(v, f + offs[0], offs[-1] - offs[0] + 1)
    x0 = int(np.clip(x - S / 2, 0, common.W - S)); y0 = int(np.clip(y - S / 2, 0, common.H - S))
    sheet = Image.new('RGB', (len(offs) * S * Z, S * Z + 26), (0, 0, 0)); d = ImageDraw.Draw(sheet)
    for c, o in enumerate(offs):
        if o - offs[0] < len(F): sheet.paste(Image.fromarray(F[o - offs[0]][y0:y0 + S, x0:x0 + S]).resize((S * Z, S * Z), Image.BICUBIC), (c * S * Z, 26))
    cx, cy = (len(offs) // 2) * S * Z + (x - x0) * Z, 26 + (y - y0) * Z
    d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), outline=(255, 0, 255), width=2)
    d.text((6, 4), title, font=SMALL, fill=(255, 255, 255))
    sheet.save(out, quality=88)
