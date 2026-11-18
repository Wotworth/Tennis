"""Learned clay run: 12 random tracked points (raw pixels from each frame's shift in the per-clip
CSVs) on review sheets: five frames around each, 4x. Writes check3L/spots.csv and spots_NN.jpg."""
import numpy as np, glob, os, common
SUF = os.environ.get('SUF', '')
from PIL import Image, ImageDraw
OUT = f'/home/user/private-footage/check3L{SUF}'
T = np.loadtxt(f'{OUT}/tracked.csv', delimiter=',', ndmin=2)
shift = {}
for f in sorted(glob.glob(f'/home/user/private-footage/run3L{SUF}/pre/clip_*.csv')):
    A = np.loadtxt(f, delimiter=',', skiprows=1, ndmin=2)
    for fr, du, dv in A[:, [0, 9, 10]]: shift[int(fr)] = (du, dv)
rng = np.random.default_rng(18)
pick = T[rng.choice(len(T), 12, replace=False)]
pick = pick[np.argsort(pick[:, 1])]
rows = []
for r, fr, u, v, tid in pick:
    du, dv = shift.get(int(fr), (0, 0)); rows.append((int(r), int(fr), u + du, v + dv))
np.savetxt(f'{OUT}/spots.csv', np.array(rows), delimiter=',', fmt='%.2f')
C, Z, per = 64, 4, 6
for s0 in range(0, len(rows), per):
    sheet = Image.new('RGB', (5 * C * Z + 80, per * C * Z), (40, 40, 40)); d = ImageDraw.Draw(sheet)
    for j, (r, fr, x, y) in enumerate(rows[s0:s0 + per]):
        F = common.read(3, fr - 6, 13)
        for c, dt in enumerate((-6, -3, 0, 3, 6)):
            img = Image.fromarray(F[6 + dt]).crop((int(x) - C // 2, int(y) - C // 2, int(x) + C // 2, int(y) + C // 2)).resize((C * Z, C * Z), Image.LANCZOS)
            if dt == 0: ImageDraw.Draw(img).ellipse((C * Z // 2 - 30, C * Z // 2 - 30, C * Z // 2 + 30, C * Z // 2 + 30), outline=(0, 255, 255), width=2)
            sheet.paste(img, (80 + c * C * Z, j * C * Z))
        d.text((4, j * C * Z + 8), '#%d' % (s0 + j), fill=(255, 255, 255)); d.text((4, j * C * Z + 24), 'f%d' % fr, fill=(200, 200, 200))
    sheet.save(f'{OUT}/spots_{s0 // per:02d}.jpg', quality=90)
print(len(rows), 'spots')
