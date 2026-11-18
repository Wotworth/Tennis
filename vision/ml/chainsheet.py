"""Round 3: a random sample of points on the round-2 model's confident chains in unseen clay
stretches, to see what its mistakes are (context crops, 96 px at 2x; three moments)."""
import numpy as np, glob, sys, common, tracker as T
from PIL import Image, ImageDraw
D_ = sys.argv[1]; rng = np.random.default_rng(7); cand = []
for f in sorted(glob.glob(f'{D_}/v4_*.npy')):
    if f.endswith('_mine.npz'): continue
    D = np.load(f); Ds, ch = T.chains(D[D[:, 3] > 0.05]) if len(D) else (D, [])
    for ci, (val, p) in enumerate(ch):
        if val < 20 or len(p) < 15: continue
        r = Ds[p]; ext = np.hypot(np.ptp(r[:, 1]), np.ptp(r[:, 2]))
        for i in rng.choice(len(p), min(2, len(p)), replace=False): cand.append((f, ci, val, len(p), ext, r[i]))
print(len(cand), 'candidate points on confident chains')
pick = [cand[i] for i in rng.choice(len(cand), min(48, len(cand)), replace=False)]
C, Z = 96, 2
for s0 in range(0, len(pick), 8):
    sheet = Image.new('RGB', (3 * C * Z + 150, 8 * C * Z), (40, 40, 40)); d = ImageDraw.Draw(sheet)
    for j, (f, ci, val, n, ext, r) in enumerate(pick[s0:s0 + 8]):
        fr, x, y = int(r[0]), r[1], r[2]; F = common.read(4, fr - 6, 13)
        for c, dt in enumerate((-6, 0, 6)):
            img = Image.fromarray(F[6 + dt]).crop((int(x) - C // 2, int(y) - C // 2, int(x) + C // 2, int(y) + C // 2)).resize((C * Z, C * Z), Image.LANCZOS)
            if dt == 0: ImageDraw.Draw(img).ellipse((C * Z // 2 - 16, C * Z // 2 - 16, C * Z // 2 + 16, C * Z // 2 + 16), outline=(0, 255, 255), width=2)
            sheet.paste(img, (150 + c * C * Z, j * C * Z))
        d.text((4, j * C * Z + 8), '#%d' % (s0 + j), fill=(255, 255, 255))
        d.text((4, j * C * Z + 26), 'worth %.0f\n%d pts\nmoved %.0f px\nscore %.2f\n(%d,%d)' % (val, n, ext, r[3], x, y), fill=(200, 200, 200))
    sheet.save('/tmp/claude-0/scratchpad/par/chain_%d.jpg' % (s0 // 8), quality=85)
