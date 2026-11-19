"""Of the spots round 4's tracker follows on new footage: how many are lighter than their surround,
darker with a colour change, and darker with none (the shadow rule)? And a by-eye sheet of the
last group, to count real balls among them (what round 5 gives up).
Usage: darksheet.py V GLOB OUT.png [N] [SEED]   (env VIDEO_W, VIDEO_H)"""
import sys, glob, numpy as np, common, proposals as P, gen_data as G, tracker, mine5
from detect_video import stream
from PIL import Image, ImageDraw

v = int(sys.argv[1]); files = sorted(glob.glob(sys.argv[2])); out = sys.argv[3]
n = int(sys.argv[4]) if len(sys.argv) > 4 else 12; rng = np.random.default_rng(int(sys.argv[5]) if len(sys.argv) > 5 else 5)
rows = []
for path in files:
    D = np.load(path)
    if not len(D): continue
    f0, f1 = int(D[:, 0].min()), int(D[:, 0].max())
    Ds, ch = tracker.chains(D[D[:, 3] > 0.05]); best = {}
    for value, p in ch:
        for i in p:
            fr = int(Ds[i, 0])
            if fr not in best or best[fr][0] < value: best[fr] = (value, Ds[i])
    buf = {}
    for k, img in enumerate(stream(v, f0 - P.K, f1 - f0 + 1 + 2 * P.K)):
        fr = f0 - P.K + k; buf[fr] = img; c = fr - P.K; buf.pop(c - P.K - 1, None)
        if c not in best or c - P.K not in buf: continue
        r = best[c][1]; cur = buf[c]
        pa = P.moved(buf[c - P.K], *P.shift(cur, buf[c - P.K])); na = P.moved(buf[c + P.K], *P.shift(cur, buf[c + P.K]))
        X = G.crop((pa, cur, na), r[1], r[2], G.scale_of(r[6], r[7], r[8]))[None]
        con, rat = mine5.features(X)
        rows.append((c, r[1], r[2], float(con[0]), float(rat[0])))
A = np.array(rows)
light = A[:, 3] > 0.2; dark = A[:, 3] < mine5.SHADOW_DARK; flat = dark & (A[:, 4] < mine5.SHADOW_RATIO)
print('video %d: %d tracked spots; lighter than the surround %d (%.0f%%); about level %d; darker with a colour change %d (%.1f%%); darker with none %d (%.1f%%)' % (
    v, len(A), light.sum(), 100 * light.mean(), (~light & ~dark).sum(), (dark & ~flat).sum(), 100 * (dark & ~flat).mean(), flat.sum(), 100 * flat.mean()))
pick = A[flat][np.sort(rng.choice(flat.sum(), min(n, flat.sum()), replace=False))] if flat.sum() else []
S = 96; Z = 3; offs = [-4, -2, 0, 2, 4]; cols = 2; rws = (len(pick) + cols - 1) // cols
sheet = Image.new('RGB', (cols * (len(offs) * S * Z + 16), max(1, rws) * (S * Z + 18)), (0, 0, 0)); d = ImageDraw.Draw(sheet)
for k, (f, x, y, con, rat) in enumerate(pick):
    f = int(f); F = common.read(v, f - 4, 9)
    x0 = int(np.clip(x - S / 2, 0, common.W - S)); y0 = int(np.clip(y - S / 2, 0, common.H - S))
    ox, oy = (k % cols) * (len(offs) * S * Z + 16), (k // cols) * (S * Z + 18)
    for c, o in enumerate(offs):
        if 4 + o >= len(F): continue
        sheet.paste(Image.fromarray(F[4 + o][y0:y0 + S, x0:x0 + S]).resize((S * Z, S * Z), Image.BICUBIC), (ox + c * S * Z, oy + 18))
    cx, cy = ox + 2 * S * Z + (x - x0) * Z, oy + 18 + (y - y0) * Z
    d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), outline=(255, 0, 255))
    d.text((ox + 3, oy + 3), f"{k + 1}. frame {f} at ({x:.0f}, {y:.0f}), contrast {con:.2f}, colour share {rat:.2f}", fill=(255, 255, 0))
sheet.save(out); print('picks', [(k + 1, int(p[0])) for k, p in enumerate(pick)])
