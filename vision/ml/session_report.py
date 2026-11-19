"""One SwingVision export against the detector's own tracks (weak labels only).
For each point: the detector's rows (detect_points.py), chains, the one ball in play, and its
events: where one chain ends and the next begins (a hit or a bounce breaks a chain) and sharp
turns inside a chain (the same test as tv.track.splitEvents). Against the overlay (overlay.py):
  - each bounce mark: is the tracked ball within 1 m of it (on the ground, through the fitted
    camera) within 0.2 s, and is there an event there?
  - each shot label: is there an event before it that no bounce explains, and how long before?
Usage: session_report.py V OVERLAY_DIR DETECTIONS_DIR   (PYTHONPATH = vision/ml)"""
import sys, csv, os, numpy as np
import common, physics, tracker, onecam

FPS = 60.0


def ground(cam, u, v):
    d = cam.ray(u, v); s = -cam.pos[2] / d[2]; return (cam.pos + s * d)[:2]


def slope(t, P, t0):
    X = np.stack([np.ones(len(t)), t - t0, (t - t0) ** 2], axis=1)
    return np.linalg.lstsq(X, P, rcond=None)[0][1]


def turns(f, uv, w=7, min_jump=1.2, rel=0.25):
    """Frames where a 2D track changes course abruptly (tv.track.splitEvents, with its window of 7 frames)."""
    n = len(f); jump = np.zeros(n)
    for i in range(n):
        L = np.nonzero((f <= f[i]) & (f >= f[i] - 2 * w))[0]; R = np.nonzero((f >= f[i]) & (f <= f[i] + 2 * w))[0]
        if len(L) < 5 or len(R) < 5: continue
        L = L[-w:]; R = R[:w]
        vL = slope(f[L].astype(float), uv[L], f[i]); vR = slope(f[R].astype(float), uv[R], f[i])
        jump[i] = np.hypot(*(vL - vR)) / max(min_jump + rel * np.hypot(*(vL + vR)) / 2, 1e-9)
    cuts = []
    for i in range(1, n - 1):
        if jump[i] > 1 and jump[i] >= jump[i - 1] and jump[i] >= jump[i + 1] and (not cuts or f[i] - cuts[-1] > 4): cuts.append(int(f[i]))
    return cuts


def in_play(D, ch):
    """The chains that are the ball in play somewhere (the most valuable chain at each frame), in time order."""
    best = {}
    for k, (value, path) in enumerate(ch):
        for i in path:
            fr = int(D[i, 0])
            if fr not in best or best[fr][0] < value: best[fr] = (value, k)
    keep = sorted({k for _, k in best.values()}, key=lambda k: D[ch[k][1][0], 0])
    out = []
    for k in keep:
        rows = np.array([i for i in ch[k][1] if best[int(D[i, 0])][1] == k])
        if len(rows) >= 3: out.append(D[rows][:, :3])
    return out


def events(cam, tracks, join=15, min_pts=8, max_rms=3.0, unclear=20):
    """[(frame, kind)] for the ball in play. The chains are strung together in time; every abrupt
    change of course in the picture is a candidate cut; neighbours are merged while one flight
    under gravity and drag, seen through the fitted camera, explains both (onecam.flights). What
    is left that is a real flight (min_pts detections, within max_rms px) is kept, and an event
    ('turn': a hit, a bounce or the net) lies between each flight and the next. The short pieces
    no flight fits sit on the events themselves. 'start' is the first flight's first frame (a
    hit, if the ball was not in view before); 'unclear' marks a gap between flights of more
    than `unclear` frames with tracked points in it, where two events may hide as one; 'end'
    the last flight's last frame."""
    if not tracks: return []
    T = np.concatenate(tracks); T = T[np.argsort(T[:, 0], kind='stable')]
    f = T[:, 0].astype(int)
    ev = []
    for run in np.split(np.arange(len(f)), np.nonzero(np.diff(f) > join)[0] + 1):
        fr, uv = f[run], T[run, 1:3]
        if len(fr) < min_pts: continue
        with np.errstate(all='ignore'):
            segs = onecam.flights(cam, fr.astype(float), uv, set(turns(fr, uv)), FPS)
        good = [(int(fr[a]), int(fr[b - 1])) for a, b, rms, x in segs if b - a >= min_pts and rms <= max_rms]
        if not good: continue
        ev.append((good[0][0], 'start'))
        for g1, g2 in zip(good[:-1], good[1:]):
            ev.append(((g1[1] + g2[0]) // 2, 'turn'))
            if g2[0] - g1[1] > unclear and np.sum((fr > g1[1]) & (fr < g2[0])) >= 5: ev.append(((g1[1] + g2[0]) // 2, 'unclear'))
        ev.append((good[-1][1], 'end'))
    return sorted(ev)


def main(v, ovl, det):
    cam = physics.Camera(v)
    rd = lambda name: list(csv.DictReader(open(f'{ovl}/v{v}_{name}.csv')))
    P, S, B = rd('points'), rd('shots'), rd('bounces')
    rows = []; tot = dict(points=0, frames=0, tracked=0, shots=0, marks=0, near=0, at_event=0, events=0, shot_event=0, extra=0, sv=0, unclear=0, missed=0, missed_prop=0, missed_scored=0)
    dts = []; lags = []; log = []
    only = [int(x) for x in os.environ.get('POINTS', '').split(',') if x]
    for p in P:
        i = int(p['point']); path = f'{det}/v{v}_p{i:03d}.npy'
        if not os.path.exists(path) or (only and i not in only): continue
        Dall = np.load(path); D = Dall[Dall[:, 3] > 0.05]
        D, ch = tracker.chains(D) if len(D) else (D, [])
        tracks = in_play(D, ch); ev = events(cam, tracks)
        ball = {int(r[0]): r[1:3] for T in tracks for r in T}
        shots = [s for s in S if int(s['point']) == i]; allm = [b for b in B if int(b['point']) == i]
        marks = [b for b in allm if b['mark'] != 'net']
        if not shots: continue
        # in play: from just before the first label to just after the last label or mark (the
        # export starts before the serve and runs on after the point: dribbles, the ball collected)
        w0 = int(shots[0]['frame']) - 30; w1 = max([int(s['frame']) for s in shots] + [int(b['frame']) for b in allm]) + 30
        ev = [e for e in ev if w0 <= e[0] <= w1]
        used = set(); near = at = 0
        for b in allm:
            fb = int(b['frame'])
            if b['mark'] != 'net':
                g = np.array([float(b['xM']), float(b['yM'])])
                d = [np.hypot(*(ground(cam, *ball[f]) - g)) for f in range(fb - 12, fb + 13) if f in ball]
                hit_near = bool(d) and min(d) < 1.0; near += hit_near
                if not hit_near:
                    qq, _ = cam.project(np.array([[g[0], g[1], 0.033]])); log.append((i, fb, 'bounce not tracked', qq[0, 0], qq[0, 1]))
                if not hit_near:
                    # the tracker has no ball there: did the motion step at least propose something at the spot?
                    # (then the classifier or the tracker lost it, and the mark can teach it)
                    q, _ = cam.project(np.array([[g[0], g[1], 0.033], [g[0], g[1] + 1.0, 0.033], [g[0] + 1.0, g[1], 0.033]]))
                    rad = max(15.0, np.hypot(*(q[1] - q[0])), np.hypot(*(q[2] - q[0])))
                    k = (np.abs(Dall[:, 0] - fb) <= 3) & (np.hypot(Dall[:, 1] - q[0, 0], Dall[:, 2] - q[0, 1]) <= rad)
                    tot['missed'] += 1; tot['missed_prop'] += bool(k.any()); tot['missed_scored'] += bool((Dall[k, 3] > 0.3).any())
            c = [(abs(e[0] - fb), k) for k, e in enumerate(ev) if abs(e[0] - fb) <= 9 and e[1] == 'turn' and k not in used]
            if c:
                k = min(c)[1]; used.add(k)
                if b['mark'] != 'net': at += 1; dts.append(ev[k][0] - fb)
        hit = 0
        for s in shots:                     # the label follows its hit: the last turn or first sight before it that no bounce took
            fs = int(s['frame'])
            c = [(fs - e[0], k) for k, e in enumerate(ev) if 0 <= fs - e[0] <= 60 and e[1] in ('turn', 'start') and k not in used]
            if c: lag, k = min(c); used.add(k); hit += 1; lags.append(lag)
        n_ev = sum(e[1] == 'turn' for e in ev); extra = sum(e[1] == 'turn' and k not in used for k, e in enumerate(ev))
        for k, e in enumerate(ev):
            if e[1] == 'turn':
                fr = min(ball, key=lambda f: abs(f - e[0])); log.append((i, e[0], 'event, SwingVision has one' if k in used else 'event, SwingVision has none', ball[fr][0], ball[fr][1]))
        n_frames = w1 - w0 + 1; seen = sum(w0 <= f <= w1 for f in ball)
        rows.append(dict(point=i, seconds=round(n_frames / FPS, 1), tracked=round(seen / n_frames, 2), shots=len(shots), bounces=len(marks), nets=len(allm) - len(marks), bouncesNear=near, bouncesAtTurn=at,
                         shotsWithTurn=hit, turns=n_ev, turnsUnmatched=extra, unclear=sum(e[1] == 'unclear' for e in ev), lost=max(sum(e[1] == 'end' for e in ev) - 1, 0)))
        for k, val in (('points', 1), ('frames', n_frames), ('tracked', seen), ('shots', len(shots)), ('marks', len(marks)), ('near', near), ('at_event', at), ('events', n_ev), ('shot_event', hit),
                       ('extra', extra), ('sv', len(shots) + len(allm)), ('unclear', sum(e[1] == 'unclear' for e in ev))): tot[k] += val
    with open(f'{ovl}/v{v}_events{"_part" if only else ""}.csv', 'w', newline='') as fh:
        w = csv.writer(fh); w.writerow(['point', 'frame', 'what', 'u', 'v']); w.writerows([(a, b, c, round(float(d), 1), round(float(e), 1)) for a, b, c, d, e in log])
    if only: return print(len(log), 'events logged')
    with open(f'{ovl}/v{v}_report.csv', 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    dts, lags = np.array(dts), np.array(lags)
    print(f"video {v}: {tot['points']} points; in play, the ball is tracked in {100 * tot['tracked'] / tot['frames']:.0f}% of frames")
    print(f"  SwingVision bounces {tot['marks']}: tracked ball within 1 m and 0.2 s of {tot['near']} ({100 * tot['near'] / max(tot['marks'], 1):.0f}%); an event within 0.15 s of {tot['at_event']} ({100 * tot['at_event'] / max(tot['marks'], 1):.0f}%)")
    print(f"    of the {tot['missed']} bounces with no tracked ball nearby: the motion step proposed a spot there for {tot['missed_prop']}, and the classifier scored one above 0.3 for {tot['missed_scored']}")
    if len(dts): print(f"    turn minus mark, frames: median {np.median(dts):+.0f}, 10th-90th {np.percentile(dts, 10):+.0f} to {np.percentile(dts, 90):+.0f}")
    print(f"  SwingVision shots {tot['shots']}: a turn (or the ball's first sight) in the second before the label, not already a bounce, for {tot['shot_event']} ({100 * tot['shot_event'] / max(tot['shots'], 1):.0f}%)")
    if len(lags): print(f"    label after it, frames: median {np.median(lags):.0f}, 10th-90th {np.percentile(lags, 10):.0f} to {np.percentile(lags, 90):.0f}")
    print(f"  turns found in play {tot['events']} against {tot['sv']} SwingVision shots, bounces and net balls; with no SwingVision counterpart {tot['extra']} ({tot['extra'] / max(tot['points'], 1):.1f} a point); unclear stretches {tot['unclear']}")


if __name__ == '__main__':
    main(int(sys.argv[1]), sys.argv[2], sys.argv[3])
