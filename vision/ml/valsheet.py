"""Check-set labelling candidates: at each check frame, every spot the classifier of either model
scores above 0.3 and each model's tracked ball, merged within 10 px; review sheets blind to the
source (five frames, 4x), as for the test set's second look. Writes valset/spots.csv, sheet_NN.jpg."""
import numpy as np, csv, common, tracker as T
from PIL import Image, ImageDraw
VAL = f'{common.ROOT}/valset'   # frames.csv and labels.csv as in vision/testset/check
F = [(int(r['i']), int(r['v']), int(r['frame'])) for r in csv.DictReader(open(f'{VAL}/frames.csv'))]
rows = []
for i, v, fr in F:
    pts = []
    for tag in ('v3o', 'self'):
        D = np.load(f'{common.ROOT}/ml/valwin/{tag}_{i:02d}.npy')
        at = D[(D[:, 0] == fr) & (D[:, 3] > 0.3)]
        pts += [(r[1], r[2]) for r in at]
        Ds, out = T.chains(D[D[:, 3] > 0.05]); b = T.ball_per_frame(Ds, out)
        if fr in b: pts.append(b[fr])
    seen = []
    for x, y in pts:
        if not any(np.hypot(x - a, y - c) <= 10 for a, c in seen): seen.append((x, y))
    rows += [(i, v, fr, x, y) for x, y in seen]
with open(f'{VAL}/spots.csv', 'w') as f:
    f.write('k,i,v,frame,x,y\n')
    for k, r in enumerate(rows): f.write('%d,%d,%d,%d,%.1f,%.1f\n' % (k, *r))
print(len(rows), 'spots in', len(F), 'frames')
C, Z, per = 64, 4, 6; cache = {}
for s0 in range(0, len(rows), per):
    sheet = Image.new('RGB', (5 * C * Z + 80, per * C * Z), (40, 40, 40)); d = ImageDraw.Draw(sheet)
    for j, (i, v, fr, x, y) in enumerate(rows[s0:s0 + per]):
        if (v, fr) not in cache: cache = {(v, fr): common.read(v, fr - 6, 13)}
        G = cache[(v, fr)]
        for c, dt in enumerate((-6, -3, 0, 3, 6)):
            img = Image.fromarray(G[6 + dt]).crop((int(x) - C // 2, int(y) - C // 2, int(x) + C // 2, int(y) + C // 2)).resize((C * Z, C * Z), Image.LANCZOS)
            if dt == 0: ImageDraw.Draw(img).ellipse((C * Z // 2 - 30, C * Z // 2 - 30, C * Z // 2 + 30, C * Z // 2 + 30), outline=(0, 255, 255), width=2)
            sheet.paste(img, (80 + c * C * Z, j * C * Z))
        d.text((4, j * C * Z + 8), '#%d' % (s0 + j), fill=(255, 255, 255)); d.text((4, j * C * Z + 24), 'c%02d' % i, fill=(200, 200, 200))
    sheet.save(f'{VAL}/sheet_{s0 // per:02d}.jpg', quality=88)
