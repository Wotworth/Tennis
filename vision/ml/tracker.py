"""One ball in play: chains of classifier detections through time.
Each detection is worth logit(score) (positive when the classifier says ball, negative when not).
A chain may link two detections up to GAP frames apart if the speed between them is one a ball
can have there (from its diameter: up to 12 diameters a frame plus a margin) and its direction
and speed change little from the chain's last step (gravity and drag change them slowly; a hit or
a bounce is a new chain). The best chain is taken, its detections removed, and so on, while a
chain is worth at least MIN_VALUE. Where chains overlap in time, the more valuable one is the ball."""
import numpy as np

GAP = 8            # frames a chain may jump over (the ball behind a player or the net)
GAP_COST = 0.4     # per missing frame
TURN_COST = 0.15   # per pixel per frame of change in velocity
MIN_VALUE = 6.0    # a chain worth less is not kept
MIN_LEN = 5


def logit(s):
    s = np.clip(s, 1e-4, 1 - 1e-4)
    return np.log(s / (1 - s))


def chains(D, step=1):
    """D: rows [frame, x, y, score, area, length, width, dmin, dmax]. Returns a list of chains, each
    an array of row indices, best first."""
    D = D[np.argsort(D[:, 0])]
    alive = np.ones(len(D), bool)
    w = np.clip(logit(D[:, 3]), -6, 6)
    frames = D[:, 0].astype(int)
    order = np.arange(len(D))
    starts = {}
    for i, f in enumerate(frames):
        starts.setdefault(f, []).append(i)
    uniq = np.array(sorted(starts))
    out = []
    while True:
        val = np.full(len(D), -np.inf); pred = np.full(len(D), -1); vel = np.zeros((len(D), 2))
        for f in uniq:
            for b in starts[f]:
                if not alive[b]: continue
                best, bp, bv = w[b], -1, np.zeros(2)
                dm = 0.5 * (D[b, 7] + D[b, 8]); vmax = 12 * max(dm, 3) + 6
                for g in range(step, GAP + 1, step):
                    for a in starts.get(f - g, ()):
                        if not alive[a] or not np.isfinite(val[a]): continue
                        d = D[b, 1:3] - D[a, 1:3]; v = d / g
                        if np.hypot(*v) > vmax: continue
                        turn = np.hypot(*(v - vel[a])) if pred[a] >= 0 else 0.0
                        c = val[a] + w[b] - GAP_COST * (g - step) / step - TURN_COST * turn
                        if c > best: best, bp, bv = c, a, v
                val[b], pred[b], vel[b] = best, bp, bv
        if not np.isfinite(val).any(): break
        e = int(np.nanargmax(np.where(alive, val, -np.inf)))
        if val[e] < MIN_VALUE: break
        path = [e]
        while pred[path[-1]] >= 0: path.append(pred[path[-1]])
        path = path[::-1]
        alive[path] = False
        if len(path) >= MIN_LEN: out.append((val[e], np.array(path)))
        # anything within 3 px of the chain at the same frame is the same object
        for i in path:
            same = (frames == frames[i]) & (np.hypot(D[:, 1] - D[i, 1], D[:, 2] - D[i, 2]) < 3)
            alive[same] = False
    return D, out


def ball_per_frame(D, out):
    """The ball in play per frame: the most valuable chain there."""
    best = {}
    for value, path in out:
        for i in path:
            f = int(D[i, 0])
            if f not in best or best[f][0] < value: best[f] = (value, D[i, 1], D[i, 2])
    return {f: (x, y) for f, (_, x, y) in best.items()}
