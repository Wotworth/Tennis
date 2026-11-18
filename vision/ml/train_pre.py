"""Train the first-pass classifier (model.PreNet) on the round-4 examples and set its threshold:
the highest that still passes 99.8% of the ball examples. Prints how many not-ball examples it
throws out. Usage: train_pre.py EPOCHS OUT.pt"""
import numpy as np, torch, sys, os, time, json, model as Mdl, train as TR
torch.set_num_threads(int(os.environ.get('THREADS', 4)))
rng = np.random.default_rng(1)
X, M, Y = TR.load([1, 2, 3, 4]); n = len(Y); print('examples', n, 'balls', int(Y.sum()), flush=True)
net = Mdl.PreNet(); epochs = int(sys.argv[1])
opt = torch.optim.AdamW(net.parameters(), 3e-3, weight_decay=1e-4)
sched = torch.optim.lr_scheduler.OneCycleLR(opt, 5e-3, total_steps=epochs * (n // 512 + 1))
lossf = torch.nn.BCEWithLogitsLoss(pos_weight=torch.tensor(3.0))     # missing a ball costs more than passing a non-ball
keep_inp = Mdl.INPUT; Mdl.INPUT = 'grey'
for ep in range(epochs):
    net.train(); perm = rng.permutation(n); tot = 0; t0 = time.time()
    for k in range(0, n, 512):
        idx = perm[k:k + 512]
        x, m = Mdl.prepare_pre(Mdl.augment(X[idx], rng), M[idx])
        loss = lossf(net(x, m), torch.from_numpy(Y[idx]))
        opt.zero_grad(); loss.backward(); opt.step(); sched.step(); tot += loss.item() * len(idx)
    print('epoch %d loss %.4f (%.0f s)' % (ep + 1, tot / n, time.time() - t0), flush=True)
net.eval(); P = []
with torch.no_grad():
    for k in range(0, n, 2048): P.append(torch.sigmoid(net(*Mdl.prepare_pre(X[k:k + 2048], M[k:k + 2048]))).numpy())
P = np.concatenate(P); pos = np.sort(P[Y == 1]); thr = float(pos[int(0.002 * len(pos))])
print('threshold %.4f: balls passed %.2f%%, not-balls thrown out %.1f%%' % (thr, 100 * (P[Y == 1] >= thr).mean(), 100 * (P[Y == 0] < thr).mean()))
torch.save(net.state_dict(), sys.argv[2]); json.dump({'threshold': thr}, open(sys.argv[2] + '.json', 'w'))
