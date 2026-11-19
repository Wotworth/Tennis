"""SwingVision overlay reader: a source of weak labels only (never the test set; TV-DET-04).
SwingVision exports are cut into points and burn a mini court and a shot label into the top-right
corner; there is no data file. This reads, per export: the points (from the overlay's own resets),
each shot's label (colour, two words, speed, unit) and each mark on the mini court (a filled dot =
a bounce SwingVision called in, a ring = out, a ring on the net line = a net ball) in court metres.
Deliberately minimal: the layout is found from the mini court's own lines, and words and digits are
matched against the few SwingVision uses (overlay_words.json), not read by general OCR.

  overlay.py prep VIDEO TAG   one pass over the export: TAG_ovl.mp4 (the corner, near-lossless) and
                              TAG_thumb.gray (a tiny grey picture of every frame)
  overlay.py read TAG         TAG_points.csv, TAG_shots.csv, TAG_bounces.csv (TAG_scan.pkl caches the scan)

What the two exports of Nov 2025 showed (docs/reports/OVERLAY-READER-1.md): the label's colour is the
stroke (green forehand, orange backhand or second serve, blue first serve, yellow volley, white
feed), not the player; a mark appears on the frame of the bounce, give or take a frame, but drifts
early when the export is not exactly 60 fps; an unknown word or digit reads as '?' and is counted.
Written for 1920x1080 exports with the overlay in the top-right corner (CX0, CY0, the templates).
"""
import pickle
import os, sys, subprocess, json, csv, numpy as np
from scipy import ndimage

CW, CH = 300, 480                 # the corner cut out of a 1920x1080 export, at (1620, 0)
CX0, CY0 = 1620, 0
TW, TH = 64, 36                   # thumbnail of the whole frame, for cuts
COURT_W, COURT_L = 10.97, 23.77   # doubles court, metres
HERE = os.path.dirname(os.path.abspath(__file__))


def prep(video, tag):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-filter_complex',
                    f'[0:v]split=2[a][b];[a]crop={CW}:{CH}:{CX0}:{CY0}[o1];[b]scale={TW}:{TH},format=gray[o2]',
                    '-map', '[o1]', '-an', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '12', '-pix_fmt', 'yuv444p',
                    f'{tag}_ovl.mp4', '-map', '[o2]', '-fps_mode', 'passthrough', '-f', 'rawvideo', f'{tag}_thumb.gray'], check=True)
    # passthrough: every source frame exactly once, so frame numbers match the footage (without it
    # ffmpeg dropped 12 of video 2's 20,462 frames and the dots drifted up to 10 frames early)


def frames(tag, chunk=240):
    """The corner video, chunk by chunk: (first frame index, (n, CH, CW, 3) uint8)."""
    p = subprocess.Popen(['ffmpeg', '-v', 'fatal', '-i', f'{tag}_ovl.mp4', '-fps_mode', 'passthrough', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    k = 0
    while True:
        raw = p.stdout.read(chunk * CW * CH * 3)
        n = len(raw) // (CW * CH * 3)
        if n == 0: break
        yield k, np.frombuffer(raw[:n * CW * CH * 3], np.uint8).reshape(n, CH, CW, 3)
        k += n
    p.wait()


def white(F): return F.min(axis=-1) > 150


def coloured(F):
    """Overlay colour (words and dots): strongly coloured and bright. The panel dims the footage
    behind it to about a quarter, so nothing of the scene passes."""
    mx, mn = F.max(axis=-1).astype(np.int16), F.min(axis=-1)
    return (mx - mn > 80) & (mx > 140)


HUES = [('red', 0), ('orange', 32), ('yellow', 55), ('green', 135), ('cyan', 180), ('blue', 220), ('purple', 275), ('pink', 320), ('red', 360)]


def hue_name(rgb):
    r, g, b = [float(v) for v in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 1: return 'none'
    h = 60 * ((g - b) / (mx - mn) % 6) if mx == r else 60 * ((b - r) / (mx - mn) + 2) if mx == g else 60 * ((r - g) / (mx - mn) + 4)
    return min(HUES, key=lambda t: abs(t[1] - h))[0]


def sample(tag, step=240):
    """Every step-th frame of the corner video."""
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', f'{tag}_ovl.mp4', '-vf', f"select='not(mod(n,{step}))'", '-fps_mode', 'passthrough',
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, CH, CW, 3)


def court_rect(tag):
    """The mini court's doubles rectangle (xL, yT, xR, yB), sub-pixel, from the thin bright lines
    of the picture's median over time (dots and labels come and go; the lines stay); checked
    against a real court's proportions."""
    m = np.median(sample(tag), axis=0).min(axis=-1).astype(np.float32)        # whiteness
    ridge = m - ndimage.median_filter(m, 9)                                   # thin and brighter than its surroundings
    L = ridge * (ridge > 35)

    def lines(count, need):
        idx = np.where(count >= need)[0]
        out = []
        for g in np.split(idx, np.where(np.diff(idx) > 1)[0] + 1):
            if len(g): out.append(float((g * count[g]).sum() / count[g].sum()))
        return out
    need = 0.2 * L.max() * 90
    xs = lines(L.sum(axis=0), need); ys = lines(L.sum(axis=1), need)
    # singles lines 1.37 m in from each side, service lines 6.40 m from the net, the net halfway
    expect_x = [0, 1.372 / COURT_W, 0.5, 1 - 1.372 / COURT_W, 1]
    expect_y = [0, 0.5 - 6.401 / COURT_L, 0.5, 0.5 + 6.401 / COURT_L, 1]

    def fit(c, expect):
        """The first and last of the candidate lines that put a line at every expected place."""
        best = None
        for i in range(len(c)):
            for j in range(i + 1, len(c)):
                err = [min(abs((x - c[i]) / (c[j] - c[i]) - e) for x in c) for e in expect]
                if max(err) < 0.015 and (best is None or c[j] - c[i] > best[1] - best[0]): best = (c[i], c[j], max(err))
        return best
    fx, fy = fit(xs, expect_x), fit(ys, expect_y)
    if fx is None or fy is None: raise RuntimeError(f'mini court not found among lines at x {xs}, y {ys}')
    return (fx[0], fy[0], fx[1], fy[1]), {'worst': max(fx[2], fy[2])}


def to_metres(r, px, py):
    """Mini-court pixel to court metres in the pipeline's axes: x along the court (net 0, the far
    end positive), y across (left of the picture positive). The exports draw the camera's end at
    the bottom; the detector's own bounces agree (delay.py: median 0.14 m apart on 40 bounces)."""
    return (0.5 - (py - r[1]) / (r[3] - r[1])) * COURT_L, (0.5 - (px - r[0]) / (r[2] - r[0])) * COURT_W


def regions(r):
    """Pixel boxes (x0, y0, x1, y1) laid out relative to the court rectangle (scale-free)."""
    w = r[2] - r[0]
    c = lambda a: tuple(int(round(v)) for v in a)
    return {'dots': c((r[0] - 0.2 * w, r[1] - 0.18 * w, r[2] + 0.2 * w, r[3] + 0.18 * w)),
            'words': c((r[0] - 0.19 * w, r[3] + 0.42 * w, r[0] + 0.66 * w, r[3] + 0.83 * w)),
            'speed': c((r[0] + 0.70 * w, r[3] + 0.42 * w, r[2] + 0.19 * w, r[3] + 0.83 * w))}


def scan(tag, r):
    """Every frame's overlay: dots [(x, y, area, colour, core, w, h)] (core 0 = a ring), the
    words' and the speed's bit masks, and the words' mean colour (RGB; zeros = no label)."""
    R = regions(r)
    dx0, dy0, dx1, dy1 = R['dots']; wx0, wy0, wx1, wy1 = R['words']; sx0, sy0, sx1, sy1 = R['speed']
    dots, words, speed, colour = [], [], [], []
    grow = np.ones((5, 5), bool)
    lines_px = None
    for k, F in frames(tag):
        D = F[:, dy0:dy1, dx0:dx1]
        M = coloured(D); Wt = white(D)
        if lines_px is None: lines_px = int(np.median(Wt.reshape(len(F), -1).sum(1)))      # the court lines' own white ink
        for i in range(len(F)):
            here = []
            # white marks: what is left of the white ink once the thin court lines are opened away
            blobs = [(M[i], None)]
            if Wt[i].sum() > lines_px + 30: blobs.append((ndimage.binary_opening(Wt[i], structure=np.ones((5, 5), bool)), 'white'))
            for mask, fixed in blobs:
                if mask.sum() < 6: continue
                lab, n = ndimage.label(ndimage.binary_dilation(mask, grow))        # a ring's arcs join up
                lab = lab * mask
                for j, sl in enumerate(ndimage.find_objects(lab)):
                    if sl is None: continue
                    part = lab[sl] == j + 1
                    a = int(part.sum())
                    if a < 6: continue
                    cy, cx = ndimage.center_of_mass(part)
                    hh, ww = part.shape
                    core = part[max(0, hh // 2 - 1):hh // 2 + 2, max(0, ww // 2 - 1):ww // 2 + 2].mean()   # a ring is empty in the middle
                    if core < 0.5: cy, cx = (hh - 1) / 2, (ww - 1) / 2            # a ring: its box's middle (the court lines cut arcs out of it)
                    here.append((dx0 + sl[1].start + cx, dy0 + sl[0].start + cy, a, fixed or hue_name(D[i][sl][part].mean(0)), float(core), ww, hh))
            dots.append(here)
        Wd = F[:, wy0:wy1, wx0:wx1]
        mc, mw = coloured(Wd), white(Wd)                                   # most labels are coloured by stroke; some are white
        m = mc | mw
        nc, nw = mc.reshape(len(F), -1).sum(1), mw.reshape(len(F), -1).sum(1)
        n = nc + nw
        col = (Wd * mc[..., None]).reshape(len(F), -1, 3).sum(1) / np.maximum(nc, 1)[:, None]
        col[nw > nc] = 255                                                 # white words
        box = F[:, wy0:wy1, wx0:sx1].max(axis=-1)
        shown = (box < 110).reshape(len(F), -1).mean(1) > 0.6        # the label's dark box is there (else this is bare footage)
        col[(n < 40) | ~shown] = 0
        words.append(np.packbits(m.reshape(len(F), -1), axis=1))
        speed.append(np.packbits(white(F[:, sy0:sy1, sx0:sx1]).reshape(len(F), -1), axis=1))
        colour.append(col)
    return dots, np.concatenate(words), np.concatenate(speed), np.concatenate(colour)


_POP = np.array([bin(i).count('1') for i in range(256)], np.uint16)


def states(words, speed, colour, word_tol=0.25, speed_tol=12, min_len=6):
    """Runs of frames showing the same label: [(first, last, colour)]. The words may differ by a
    quarter of their pixels (video compression frays the letters' edges; different words differ
    by far more), the speed by a dozen pixels. A label that fades in or out is not a run; two
    identical labels in a row cannot be told apart (reported as one)."""
    out = []; a = 0; n = len(words)
    nw = _POP[words].sum(1)
    name = np.array(['' if not c.any() else 'white' if c.min() == 255 else hue_name(c) for c in colour])
    while a < n:
        if name[a] == '': a += 1; continue
        ref = min(a + 3, n - 1)                       # a few frames in, past any fade
        b = a + 1
        while b < n and name[b] == name[a] and _POP[words[b] ^ words[ref]].sum() <= word_tol * nw[ref] \
                and _POP[speed[b] ^ speed[ref]].sum() <= speed_tol: b += 1
        if b - a >= min_len: out.append((a, b - 1, str(name[a]))); a = b
        else: a += 1
    return out


def new_dots(dots, near=4.0, min_len=8, settle=(12, 40)):  # colour: a hue name
    """Each dot's first frame and settled position: [(first, last, x, y, colour, fill, size)]."""
    live = []; done = []
    for f, here in enumerate(dots):
        for d in live: d['seen'] = False
        for (x, y, a, c, fill, ww, hh) in here:
            for d in live:
                if d['c'] == c and abs(d['x'] - x) <= near and abs(d['y'] - y) <= near and not d['seen']:
                    d['seen'] = True; d['last'] = f; d['obs'].append((f, x, y, a, fill, max(ww, hh))); break
            else:
                live.append({'c': c, 'x': x, 'y': y, 'first': f, 'last': f, 'seen': True, 'obs': [(f, x, y, a, fill, max(ww, hh))]})
        keep = []
        for d in live:
            if f - d['last'] > 3: done.append(d)
            else: keep.append(d)
        live = keep
    out = []
    for d in done + live:
        if d['last'] - d['first'] + 1 < min_len: continue
        o = np.array(d['obs']); s = o[(o[:, 0] >= d['first'] + settle[0]) & (o[:, 0] <= d['first'] + settle[1])]
        if len(s) == 0: s = o
        out.append((d['first'], d['last'], float(np.median(s[:, 1])), float(np.median(s[:, 2])), d['c'], float(np.median(s[:, 4])), float(np.median(s[:, 5]))))
    return sorted(out)


def thumb_jumps(tag):
    """How much the picture changes from each frame to the next, away from the right-hand side
    (the overlay's own boxes pop in and out there, a second into each point)."""
    T = np.fromfile(f'{tag}_thumb.gray', np.uint8).reshape(-1, TH, TW)[:, :, :int(TW * 0.72)].astype(np.int16)
    return np.concatenate([[0], np.abs(np.diff(T, axis=0)).reshape(len(T) - 1, -1).mean(1)])


def unpack(bits, box):
    h, w = box[3] - box[1], box[2] - box[0]
    return np.unpackbits(bits)[:h * w].reshape(h, w).astype(bool)


def majority(masks, a, b, box):
    """The label as most frames of a run show it (frayed edges voted away)."""
    M = np.stack([unpack(masks[f], box) for f in range(a, b + 1, max(1, (b - a) // 15))])
    return M.mean(0) > 0.5


def text_lines(m, min_px=3):
    """Split a text mask into lines, each trimmed to its ink: [(y0, x0, mask)]."""
    rows = np.where(m.sum(1) >= 1)[0]
    out = []
    if len(rows) == 0: return out
    for g in np.split(rows, np.where(np.diff(rows) > 2)[0] + 1):
        part = m[g[0]:g[-1] + 1]
        if part.sum() < min_px * 4: continue
        cols = np.where(part.sum(0) >= 1)[0]
        out.append((int(g[0]), int(cols[0]), part[:, cols[0]:cols[-1] + 1]))
    return out


def glyphs(line):
    """Split one line of text into characters at empty columns: [(x0, mask)]."""
    cols = np.where(line.sum(0) >= 1)[0]
    out = []
    for g in np.split(cols, np.where(np.diff(cols) > 1)[0] + 1):
        part = line[:, g[0]:g[-1] + 1]
        rows = np.where(part.sum(1) >= 1)[0]
        out.append((int(g[0]), part[rows[0]:rows[-1] + 1]))
    return out


def same(a, b, tol=0.25):
    """Two trimmed masks show the same word or digit: sizes within 2 px and, at the best 1 px
    shift, differing in under a quarter of their ink."""
    if abs(a.shape[0] - b.shape[0]) > 2 or abs(a.shape[1] - b.shape[1]) > 2: return False
    h, w = max(a.shape[0], b.shape[0]) + 2, max(a.shape[1], b.shape[1]) + 2
    A = np.zeros((h, w), bool); A[1:1 + a.shape[0], 1:1 + a.shape[1]] = a
    best = 1e9
    for dy in range(3):
        for dx in range(3):
            if dy + b.shape[0] > h or dx + b.shape[1] > w: continue
            B = np.zeros((h, w), bool); B[dy:dy + b.shape[0], dx:dx + b.shape[1]] = b
            best = min(best, (A ^ B).sum())
    return best <= tol * max(a.sum(), b.sum())


def load_templates(path=None):
    """The words and digits SwingVision's label uses, as small ink masks (overlay_words.json).
    Each was grouped from the exports themselves and named once by eye."""
    T = json.load(open(path or os.path.join(HERE, 'overlay_words.json')))
    un = lambda t: (t['name'], np.array([[ch == '#' for ch in row] for row in t['rows']]))
    return {'words': [un(t) for t in T['words']], 'digits': [un(t) for t in T['digits']]}


def name_of(m, templates):
    for name, t in templates:
        if same(t, m): return name
    return '?'


def read_label(wm, sm, T):
    """One label's masks to (line 1, line 2, speed, unit), e.g. ('Topspin', 'Forehand', '41', 'MPH');
    '?' marks ink no template matches."""
    w = [name_of(m, T['words']) for _, _, m in text_lines(wm)]
    S = text_lines(sm)
    speed = ''.join(name_of(g, T['digits']) for _, g in glyphs(S[0][2])) if S else ''
    unit = name_of(S[1][2], T['words']) if len(S) > 1 else ''
    return (w + ['', ''])[0], (w + ['', ''])[1], speed, unit


def points(dots, sts, jumps, gap=45, quiet=10):
    """Point boundaries: [(first frame, last frame)]. A cut shows twice. The picture jumps for a
    single frame (the camera is fixed, so the jump can be small: it is judged against the frames
    either side). And SwingVision clears the mini court's marks and the label, 3 to 25 frames
    later. Every clear jump is a cut; a clearing with no clear jump before it is one too, placed
    at the largest jump just before it. Clips under half a second are joined to the next."""
    n = len(dots)
    near = lambda k: np.r_[jumps[max(1, k - 8):max(1, k - 1)], jumps[k + 2:k + 9]]
    ratio = np.array([jumps[k] / (np.median(near(k)) + 0.05) if 8 < k < n - 9 else 0 for k in range(n)])
    cuts = []
    for k in np.where((ratio > 4) & (jumps > 1.5))[0]:
        if cuts and k - cuts[-1] <= 5:
            if jumps[k] > jumps[cuts[-1]]: cuts[-1] = int(k)
        else: cuts.append(int(k))
    has = np.array([len(d) > 0 for d in dots])
    resets = [f for f in np.where(has[:-1] & ~has[1:])[0] + 1 if not has[f:f + quiet].any()]     # gone, and staying gone
    resets = [f for f in resets if not any(a <= f + quiet and b >= f for a, b, _ in sts)]            # and the label gone with them (a feed's white dot goes on its own)
    for i in range(len(sts) - 1):                                          # a point with no marks: the label goes
        if sts[i + 1][0] - sts[i][1] > gap and not any(sts[i][1] < x <= sts[i + 1][0] for x in resets): resets.append(sts[i][1] + 1)
    for x in sorted(resets):
        if any(x - 25 <= c <= x + 3 for c in cuts): continue
        a = max(9, x - 25); k = a + int(np.argmax(ratio[a:x + 3] * (jumps[a:x + 3] > 2)))
        cuts.append(k if ratio[k] > 1.8 and jumps[k] > 2 else max(1, x - 3))
    edges = [0]
    for c in sorted(cuts):
        if c - edges[-1] >= 30: edges.append(c)
        elif len(edges) > 1: edges[-1] = c                                  # a clip of a few frames: no point of its own
    edges.append(n)
    return [(edges[i], edges[i + 1] - 1) for i in range(len(edges) - 1)]


def read(tag, fps=60.0, templates=None):
    """Read one prepared export. Writes TAG_points.csv, TAG_shots.csv, TAG_bounces.csv and returns
    them as lists of dicts. Times are seconds into the export; frames count from 0."""
    T = load_templates(templates)
    cache = f'{tag}_scan.pkl'
    if os.path.exists(cache):
        r, dots, words, speed, colour = pickle.load(open(cache, 'rb'))
    else:
        r, _ = court_rect(tag); dots, words, speed, colour = scan(tag, r)
        pickle.dump((r, dots, words, speed, colour), open(cache, 'wb'))
    R = regions(r)
    sts = states(words, speed, colour)
    jumps = thumb_jumps(tag)
    if len(jumps) != len(dots): raise RuntimeError(f'{len(dots)} overlay frames but {len(jumps)} thumbnails: a frame was dropped or doubled')
    P = points(dots, sts, jumps)
    pt = lambda f: next((i for i, (a, b) in enumerate(P) if a <= f <= b), -1)
    shots = []
    for a, b, col in sts:
        l1, l2, spd, unit = read_label(majority(words, a, b, R['words']), majority(speed, a, b, R['speed']), T)
        shots.append({'point': pt(a), 'frame': a, 't': round(a / fps, 3), 'lastFrame': b, 'colour': col, 'line1': l1, 'line2': l2, 'speed': spd, 'unit': unit})
    bounces = []
    for first, last, x, y, col, core, size in new_dots(dots):
        xm, ym = to_metres(r, x, y)
        prev = [s for s in shots if s['frame'] <= first and s['point'] == pt(first)]
        # a filled dot is a bounce SwingVision called in; a ring is its out call, or on the net line a net ball (no bounce)
        mark = 'dot' if core >= 0.5 else 'net' if abs(xm) < 0.6 and abs(ym) < 6.0 else 'ring'
        bounces.append({'point': pt(first), 'frame': first, 't': round(first / fps, 3), 'lastFrame': last, 'colour': col, 'mark': mark,
                        'xM': round(xm, 2), 'yM': round(ym, 2), 'px': round(x, 1), 'py': round(y, 1), 'shotFrame': prev[-1]['frame'] if prev else -1})
    # one mark per event: a ring cut into arcs, or a new dot popping up against an old one, shows as
    # several marks a few frames and pixels apart; keep the first frame and the longest-lived position
    merged = []
    for b in bounces:
        twin = next((m for m in merged if b['frame'] - m['frame'] <= 40 and b['point'] == m['point'] and np.hypot(b['px'] - m['px'], b['py'] - m['py']) <= 12), None)
        if twin is None: merged.append(b); continue
        if b['lastFrame'] - b['frame'] > twin['lastFrame'] - twin['frame']:
            for k in ('lastFrame', 'colour', 'mark', 'xM', 'yM', 'px', 'py'): twin[k] = b[k]
    bounces = merged
    pts = [{'point': i, 'first': a, 'last': b, 't0': round(a / fps, 3), 't1': round(b / fps, 3),
            'shots': sum(s['point'] == i for s in shots), 'marks': sum(q['point'] == i for q in bounces)} for i, (a, b) in enumerate(P)]
    for name, rows in (('points', pts), ('shots', shots), ('bounces', bounces)):
        with open(f'{tag}_{name}.csv', 'w', newline='') as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    return pts, shots, bounces


if __name__ == '__main__':
    if sys.argv[1] == 'prep': prep(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'read':
        pts, shots, bounces = read(sys.argv[2])
        print(f'{len(pts)} points, {len(shots)} shots, {sum(b["mark"] == "dot" for b in bounces)} bounces in, {sum(b["mark"] == "ring" for b in bounces)} out, '
              f'{sum(b["mark"] == "net" for b in bounces)} net; {sum("?" in s["line1"] + s["line2"] + s["speed"] + s["unit"] for s in shots)} labels with unread ink')
