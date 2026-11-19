"""New footage, no hand labels: what the tracker's ball in play is, by the shadow rule (mine5.features).
For each detection file: the ball in play per frame, a cut at each tracked spot, and the share that are
darker than their surround with no colour change (the ball's shadow). Also the share of frames tracked.
Usage: newscore.py V GLOB   (env VIDEO_W, VIDEO_H)"""
import sys, glob, numpy as np, common, proposals as P, gen_data as G, tracker, mine5
from detect_video import stream

v = int(sys.argv[1]); files = sorted(glob.glob(sys.argv[2]))
tot = dict(frames=0, tracked=0, shadow=0, strong=0, strong_shadow=0)
for path in files:
    D = np.load(path)
    if not len(D): continue
    f0, f1 = int(D[:, 0].min()), int(D[:, 0].max()); tot['frames'] += f1 - f0 + 1
    Ds, ch = tracker.chains(D[D[:, 3] > 0.05]); best = {}
    for value, p in ch:
        for i in p:
            fr = int(Ds[i, 0])
            if fr not in best or best[fr][0] < value: best[fr] = (value, Ds[i])
    X = []; V = []; buf = {}
    for k, img in enumerate(stream(v, f0 - P.K, f1 - f0 + 1 + 2 * P.K)):
        fr = f0 - P.K + k; buf[fr] = img; c = fr - P.K; buf.pop(c - P.K - 1, None)
        if c not in best or c - P.K not in buf: continue
        r = best[c][1]; cur = buf[c]
        pa = P.moved(buf[c - P.K], *P.shift(cur, buf[c - P.K])); na = P.moved(buf[c + P.K], *P.shift(cur, buf[c + P.K]))
        X.append(G.crop((pa, cur, na), r[1], r[2], G.scale_of(r[6], r[7], r[8]))); V.append(best[c][0])
    if not X: continue
    X = np.array(X, np.uint8); V = np.array(V); con, rat = mine5.features(X); sh = (con < mine5.SHADOW_DARK) & (rat < mine5.SHADOW_RATIO)
    tot['tracked'] += len(X); tot['shadow'] += int(sh.sum()); tot['strong'] += int((V >= 20).sum()); tot['strong_shadow'] += int((sh & (V >= 20)).sum())
print('video %d, %d files: ball tracked in %d of %d frames (%.0f%%); tracked spots that are shadows by the rule: %d (%.1f%%); on confident paths (worth 20+): %d of %d (%.1f%%)' % (
    v, len(files), tot['tracked'], tot['frames'], 100 * tot['tracked'] / max(tot['frames'], 1), tot['shadow'], 100 * tot['shadow'] / max(tot['tracked'], 1),
    tot['strong_shadow'], tot['strong'], 100 * tot['strong_shadow'] / max(tot['strong'], 1)))
