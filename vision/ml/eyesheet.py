"""By-eye check of tracked spots on new footage (private frames; only the verdicts are kept).
Picks N frames at random among those where the tracker has a ball in play (from detect_points
chunks or one detect_video file) and draws, per pick, five crops (frames -4, -2, 0, +2, +4)
centred on the tracked spot, with the spot ringed in the middle crop.
Usage: eyesheet.py V N OUT.png FILE_OR_GLOB [SEED]   (env VIDEO_W, VIDEO_H for other frame sizes)"""
import sys, glob, numpy as np, common, tracker
from PIL import Image, ImageDraw

v, n, out, pat = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
rng = np.random.default_rng(int(sys.argv[5]) if len(sys.argv) > 5 else 1)
cand = []; total = 0; frames = 0
for path in sorted(glob.glob(pat)):
    D = np.load(path)
    if len(D) == 0: continue
    frames += int(D[:, 0].max() - D[:, 0].min()) + 1
    D = D[D[:, 3] > 0.05]
    Ds, ch = tracker.chains(D); ball = tracker.ball_per_frame(Ds, ch)
    val = {}
    for value, pth in ch:
        for i in pth:
            f = int(Ds[i, 0])
            if f in ball and abs(Ds[i, 1] - ball[f][0]) < 0.6: val[f] = (value, 0.5 * (Ds[i, 7] + Ds[i, 8]))
    total += len(ball)
    cand += [(f, ball[f][0], ball[f][1], val.get(f, (0, 6))[0], val.get(f, (0, 6))[1]) for f in ball]
print('frames', frames, 'with a ball tracked', total, '(%.0f%%)' % (100 * total / max(frames, 1)))
pick = [cand[i] for i in sorted(rng.choice(len(cand), min(n, len(cand)), replace=False))]
S = 96; Z = 3; offs = [-4, -2, 0, 2, 4]; cols = 2; rows = (len(pick) + cols - 1) // cols
sheet = Image.new('RGB', (cols * (len(offs) * S * Z + 16), rows * (S * Z + 18)), (0, 0, 0)); d = ImageDraw.Draw(sheet)
for k, (f, x, y, value, dia) in enumerate(pick):
    F = common.read(v, f - 4, 9)
    x0 = int(np.clip(x - S / 2, 0, common.W - S)); y0 = int(np.clip(y - S / 2, 0, common.H - S))
    ox, oy = (k % cols) * (len(offs) * S * Z + 16), (k // cols) * (S * Z + 18)
    for c, o in enumerate(offs):
        if 4 + o >= len(F): continue
        im = Image.fromarray(F[4 + o][y0:y0 + S, x0:x0 + S]).resize((S * Z, S * Z), Image.BICUBIC)
        sheet.paste(im, (ox + c * S * Z, oy + 18))
    cx, cy = ox + 2 * S * Z + (x - x0) * Z, oy + 18 + (y - y0) * Z
    d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), outline=(255, 0, 255))
    d.text((ox + 3, oy + 3), f"{k + 1}. frame {f} at ({x:.0f}, {y:.0f}), chain worth {value:.0f}, ball here about {dia:.0f} px", fill=(255, 255, 0))
sheet.save(out); print('sheet', sheet.size, 'picks', [(k + 1, p[0]) for k, p in enumerate(pick)])
