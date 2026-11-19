"""The reader's answers on 20 shots, for checking by eye: the overlay's own ink (white, coloured;
nothing of the footage) with the newest mark boxed, and what the reader made of it."""
import overlay as O, numpy as np, csv, pickle, sys
from PIL import Image, ImageDraw, ImageFont
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
picks = []
for v, tag in ((1, 'v1'), (2, 'v2')):
    S = list(csv.DictReader(open(f'{tag}_shots.csv'))); B = list(csv.DictReader(open(f'{tag}_bounces.csv')))
    r = pickle.load(open(f'{tag}_scan.pkl', 'rb'))[0]
    idx = np.linspace(3, len(S) - 4, 10).round().astype(int)        # evenly through the export, whatever they show
    for i in idx:
        s = S[i]; m = [b for b in B if b['shotFrame'] == s['frame']]
        m = m[0] if m else None
        f = min(int(s['lastFrame']) - 2, int(m['frame']) + 25) if m and int(m['frame']) + 8 <= int(s['lastFrame']) else int(s['lastFrame']) - 2
        picks.append((v, tag, r, s, m, f))
want = {}
for v, tag, r, s, m, f in picks: want.setdefault(tag, set()).add(f)
got = {}
for tag in want:
    for k, F in O.frames(tag):
        for f in want[tag]:
            if k <= f < k + len(F): got[(tag, f)] = F[f - k].copy()
PW, PH = 300, 560
sheet = Image.new('RGB', (5 * PW, 4 * PH), (0, 0, 0)); d = ImageDraw.Draw(sheet); lines = []
for n, (v, tag, r, s, m, f) in enumerate(picks):
    F = got[(tag, f)]; R = O.regions(r)
    ink = np.zeros_like(F)
    for x0, y0, x1, y1 in (R['dots'], (R['words'][0], R['words'][1], R['speed'][2], R['words'][3])):
        part = F[y0:y1, x0:x1]; keep = O.white(part) | O.coloured(part) | (part.min(-1) > 90)
        ink[y0:y1, x0:x1] = part * keep[..., None]
    ox, oy = (n % 5) * PW, (n // 5) * PH
    sheet.paste(Image.fromarray(ink), (ox, oy))
    shown = m is not None and int(m['frame']) <= f
    if shown:
        px, py = float(m['px']), float(m['py']); d.rectangle((ox + px - 9, oy + py - 9, ox + px + 9, oy + py + 9), outline=(255, 255, 255))
    t = int(s['frame']) / 60; label = f"{s['line1']} {s['line2']} {s['speed']} {s['unit']}".strip()
    if m is None: where = 'no mark for this shot'
    else:
        x, y = float(m['xM']), float(m['yM'])
        kind = {'dot': 'bounce (in)', 'ring': 'bounce (out)', 'net': 'net'}[m['mark']]
        where = f"{kind}: {abs(x):.1f} m {'far' if x > 0 else 'near'} side, {abs(y):.1f} m {'left' if y > 0 else 'right'}" if m['mark'] != 'net' else f"net, {abs(y):.1f} m {'left' if y > 0 else 'right'} of centre"
        if not shown: where = where.replace('bounce ', '') + ' (not yet shown)'
    d.text((ox + 8, oy + 484), f"{n + 1}. video {v}, {int(t // 60)}:{t % 60:04.1f}", font=font, fill=(255, 255, 255))
    d.text((ox + 8, oy + 504), f"{label} ({s['colour']})", font=font, fill=(255, 255, 255))
    d.text((ox + 8, oy + 526), where, font=small, fill=(255, 255, 255))
    lines.append(f"| {n + 1} | {v} | {int(t // 60)}:{t % 60:04.1f} | {label} | {s['colour']} | {where} |")
    d.rectangle((ox, oy, ox + PW - 1, oy + PH - 1), outline=(70, 70, 70))
sheet.save('overlay_check_20.png'); open('overlay_check_20.md', 'w').write('\n'.join(lines) + '\n'); print('\n'.join(lines))
