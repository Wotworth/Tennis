"""Learned clay run: 10 sample frames (7 inside found points, 3 outside), full frame at 1280x720
with the tracked point(s) ringed; check3L/frames.csv and frames_NN.jpg (two per sheet)."""
import numpy as np, glob, os, common
SUF = os.environ.get('SUF', '')
from PIL import Image, ImageDraw
OUT = f'/home/user/private-footage/check3L{SUF}'
T = np.loadtxt(f'{OUT}/tracked.csv', delimiter=',', ndmin=2)
P = np.loadtxt(f'{OUT}/points.csv', delimiter=',', ndmin=2).astype(int)
C = np.loadtxt(f'{OUT}/clips.csv', delimiter=',', ndmin=2).astype(int)
shift = {}
for f in sorted(glob.glob(f'/home/user/private-footage/run3L{SUF}/pre/clip_*.csv')):
    A = np.loadtxt(f, delimiter=',', skiprows=1, ndmin=2)
    for fr, du, dv in A[:, [0, 9, 10]]: shift[int(fr)] = (du, dv)
rng = np.random.default_rng(1118)
inside = np.concatenate([np.arange(a, b) for a, b in P]); allf = np.concatenate([np.arange(a + 3, b - 3) for a, b in C])
outside = np.setdiff1d(allf, inside)
fr = np.sort(np.concatenate([rng.choice(inside, 7, replace=False), rng.choice(outside, 3, replace=False)]))
clip = [int(np.nonzero((C[:, 0] <= f) & (C[:, 1] >= f))[0][0]) + 1 for f in fr]
np.savetxt(f'{OUT}/frames.csv', np.column_stack([clip, fr]), delimiter=',', fmt='%d')
for s0 in range(0, 10, 2):
    sheet = Image.new('RGB', (1280, 2 * 720 + 10))
    for j in range(2):
        f = int(fr[s0 + j]); img = Image.fromarray(common.read(3, f, 1)[0]); d = ImageDraw.Draw(img)
        du, dv = shift.get(f, (0, 0))
        for r in T[T[:, 1] == f]:
            x, y = r[2] + du, r[3] + dv
            d.ellipse((x - 20, y - 20, x + 20, y + 20), outline=(255, 0, 255), width=3)
        d.text((10, 10), 'clip %d frame %d' % (clip[s0 + j], f), fill=(255, 255, 255))
        sheet.paste(img.resize((1280, 720)), (0, j * 730))
    sheet.save(f'{OUT}/frames_{s0 // 2:02d}.jpg', quality=85)
print(list(zip(clip, fr.tolist())))
