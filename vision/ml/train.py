"""Train the ball classifier on the generated data (CPU). Video-held-out check: train on two
videos, validate on the third, then a final model on all three."""
import numpy as np, torch, glob, sys, os, time, model as Mdl

torch.set_num_threads(4)
rng = np.random.default_rng(0)


POS = os.environ.get('POS', 'pos3d')      # which drawn-ball set to use (negatives always from the proposal shards)
EXTRA = os.environ.get('EXTRA', '')       # extra shards (self-training), glob with {v}
OLDNEG = os.environ.get('OLDNEG', '1') == '1'   # the first negatives (every proposal, real balls included)
OLDNEG_V = [int(c) for c in os.environ.get('OLDNEG_V', '123')]   # ... only from these videos (raw footage: few real balls among them)


MINED_NEG = float(os.environ.get('MINED_NEG', '1'))   # share of the mined "not a ball" examples kept


def load(videos):
    """All examples for these videos in one preallocated array (no doubled copies: the round-2
    set is about 5 GB as uint8)."""
    parts = []                                          # (file, row selection)
    for v in videos:
        for f in sorted(glob.glob(f'/home/user/private-footage/ml/data/v{v}_s*.npz')) if OLDNEG and v in OLDNEG_V else []:
            parts.append((f, np.nonzero(np.load(f)['Y'] == 0)[0]))
        for f in sorted(glob.glob(f'/home/user/private-footage/ml/data/{POS}_v{v}_*.npz')):
            parts.append((f, None))
        for pat in [e for e in EXTRA.split(';') if e]:       # several globs, ';'-separated
            for f in sorted(glob.glob(pat.replace('{v}', str(v)))):
                y = np.load(f)['Y']
                keep = (y == 1) | (rng.random(len(y)) < MINED_NEG)
                parts.append((f, np.nonzero(keep)[0]))
    n = sum(len(np.load(f)['Y']) if k is None else len(k) for f, k in parts)
    X = np.empty((n, 3, 48, 48, 3), np.uint8); M = np.empty((n, 2), np.float32); Y = np.empty(n, np.float32)
    j = 0
    for f, k in parts:
        d = np.load(f); x = d['X'] if k is None else d['X'][k]
        X[j:j + len(x)] = x; M[j:j + len(x)] = d['M'] if k is None else d['M'][k]; Y[j:j + len(x)] = d['Y'] if k is None else d['Y'][k]
        j += len(x); del x, d
    return X, M, Y


def run(train_v, val_v, epochs, out):
    X, M, Y = load(train_v)
    print('train', train_v, len(Y), 'positives', int(Y.sum()))
    net = Mdl.BallNet(); opt = torch.optim.AdamW(net.parameters(), 2e-3, weight_decay=1e-4)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, 3e-3, total_steps=epochs * (len(Y) // 256 + 1))
    lossf = torch.nn.BCEWithLogitsLoss()
    if val_v:
        Xv, Mv, Yv = load(val_v)
        keep = rng.permutation(len(Yv))[:8000]; Xv, Mv, Yv = Xv[keep], Mv[keep], Yv[keep]
    for ep in range(epochs):
        net.train(); t0 = time.time(); perm = rng.permutation(len(Y)); tot = 0
        for k in range(0, len(Y), 256):
            idx = perm[k:k + 256]
            x, m = Mdl.prepare(Mdl.augment(X[idx], rng), M[idx]); x = Mdl.train_only(x, rng)
            loss = lossf(net(x, m), torch.from_numpy(Y[idx]))
            opt.zero_grad(); loss.backward(); opt.step(); sched.step(); tot += loss.item() * len(idx)
        msg = 'epoch %d loss %.4f (%.0f s)' % (ep + 1, tot / len(Y), time.time() - t0)
        if val_v:
            net.eval()
            with torch.no_grad():
                p = torch.cat([torch.sigmoid(net(*Mdl.prepare(Xv[j:j + 1024], Mv[j:j + 1024]))) for j in range(0, len(Yv), 1024)]).numpy()
            pos, neg = p[Yv == 1], p[Yv == 0]
            msg += ' | held-out video %s: drawn balls kept at 0.5: %.3f, proposals passed: %.4f' % (val_v, (pos > 0.5).mean(), (neg > 0.5).mean())
        print(msg, flush=True)
    torch.save(net.state_dict(), out)


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'heldout':
        run([1, 2], [3], int(sys.argv[2]), sys.argv[3])
    elif mode.startswith('v'):                 # e.g. v3: train on video 3 only, check on 1 and 2
        tv = [int(c) for c in mode[1:]]
        run(tv, [v for v in (1, 2, 3) if v not in tv][:1], int(sys.argv[2]), sys.argv[3])
    else:
        # video 4 is the whole clay recording (only self-training stretches outside the test cut)
        run([1, 2, 3, 4], None, int(sys.argv[2]), sys.argv[3])
