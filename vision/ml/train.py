"""Train the ball classifier on the generated data (CPU). Video-held-out check: train on two
videos, validate on the third, then a final model on all three."""
import numpy as np, torch, glob, sys, os, time, model as Mdl

torch.set_num_threads(4)
rng = np.random.default_rng(0)


POS = os.environ.get('POS', 'pos3d')      # which drawn-ball set to use (negatives always from the proposal shards)
EXTRA = os.environ.get('EXTRA', '')       # extra shards (self-training), glob with {v}
OLDNEG = os.environ.get('OLDNEG', '1') == '1'   # the first negatives (every proposal, real balls included)
OLDNEG_V = [int(c) for c in os.environ.get('OLDNEG_V', '123')]   # ... only from these videos (raw footage: few real balls among them)


def load(videos):
    X, M, Y = [], [], []
    for v in videos:
        for f in sorted(glob.glob(f'/home/user/private-footage/ml/data/v{v}_s*.npz')) if OLDNEG and v in OLDNEG_V else []:
            d = np.load(f); k = d['Y'] == 0
            X.append(d['X'][k]); M.append(d['M'][k]); Y.append(d['Y'][k])
        for f in sorted(glob.glob(f'/home/user/private-footage/ml/data/{POS}_v{v}_*.npz')):
            d = np.load(f); X.append(d['X']); M.append(d['M']); Y.append(d['Y'])
        if EXTRA:
            for f in sorted(glob.glob(EXTRA.replace('{v}', str(v)))):
                d = np.load(f); X.append(d['X']); M.append(d['M']); Y.append(d['Y'])
    return np.concatenate(X), np.concatenate(M), np.concatenate(Y).astype(np.float32)


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
            x, m = Mdl.prepare(Mdl.augment(X[idx], rng), M[idx])
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
        run([1, 2, 3], None, int(sys.argv[2]), sys.argv[3])
