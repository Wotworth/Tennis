"""Run proposals + classifier over a stretch of a video, reading it straight through.
Writes rows [frame, x, y, score, area, length, width, dmin, dmax] (raw frame pixels) for every
proposal (score included, so the threshold can be chosen later)."""
import os, numpy as np, subprocess, sys, torch, time, common, proposals as P, gen_data as G, model as Mdl

torch.set_num_threads(1)


def stream(v, first, count):
    p = common.pts(v); t = p[first] - 0.25 / common.FPS
    cmd = ['ffmpeg', '-v', 'error', '-ss', '%.6f' % t, '-i', common.VIDEO[v], '-frames:v', str(count), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    # the check set's windows of the whole clay recording are kept as stream copies (valset/store:
    # the same compressed frames, from the keyframe before each window, with the number of frames
    # to skip beside them), so the 3 GB recording itself need not stay on the session's disk
    kept = f'{common.ROOT}/valset/store/v{v}_{first:06d}_{count}.mkv'; skip = 0
    if os.path.exists(kept):
        import json
        skip = json.load(open(kept + '.json'))['skip']
        cmd = ['ffmpeg', '-v', 'fatal', '-i', kept, '-fps_mode', 'passthrough', '-frames:v', str(count + skip), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    pr = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=10 ** 8)
    n = common.W * common.H * 3
    while True:
        b = pr.stdout.read(n)
        if len(b) < n: break
        if skip: skip -= 1; continue
        yield common.condition(np.frombuffer(b, np.uint8).reshape(common.H, common.W, 3))
    pr.wait()


def main(v, first, last, step, weights, out):
    net = Mdl.BallNet(); net.load_state_dict(torch.load(weights)); net.eval()
    # the first pass (env PRE: PreNet weights; its threshold sits beside them): what it throws out never reaches the classifier
    pre = None; T = {'proposals': 0.0, 'cut': 0.0, 'first pass': 0.0, 'classifier': 0.0}; nsp = [0, 0]
    if os.environ.get('PRE'):
        import json
        pre = Mdl.PreNet(); pre.load_state_dict(torch.load(os.environ['PRE'])); pre.eval()
        pre_thr = json.load(open(os.environ['PRE'] + '.json'))['threshold']
    dmin, dmax = common.geom(v); mask = P.mask_full(v)
    from PIL import Image
    bg = common.condition(np.asarray(Image.open(f'{common.ROOT}/ml/bg_v{v}.png').convert('RGB')))
    buf = {}; rows = []; t0 = time.time(); done = 0
    for k, f in enumerate(stream(v, first - P.K, last - first + 2 * P.K + 1)):
        fr = first - P.K + k
        buf[fr] = f
        c = fr - P.K
        buf.pop(c - P.K - 1, None)
        if c < first or (c - first) % step or c - P.K not in buf: continue
        prev, cur, nxt = buf[c - P.K], buf[c], buf[c + P.K]
        t1 = time.time(); props, _ = P.proposals(prev, cur, nxt, dmin, dmax, mask); T['proposals'] += time.time() - t1
        if len(props):
            pa = P.moved(prev, *P.shift(cur, prev)); na = P.moved(nxt, *P.shift(cur, nxt))
            hy = np.minimum(props[:, 1].astype(int) // 2, dmin.shape[0] - 1); hx = np.minimum(props[:, 0].astype(int) // 2, dmin.shape[1] - 1)
            M = np.stack([dmin[hy, hx], dmax[hy, hx]], axis=1).astype(np.float32)
            sc = np.array([G.scale_of(p[4], m[0], m[1]) for p, m in zip(props, M)], np.float32)
            t1 = time.time(); X = G.crop_batch((pa, cur, na), props[:, 0], props[:, 1], sc); T['cut'] += time.time() - t1
            Mn = M / sc[:, None]; go = np.arange(len(X)); s = np.zeros(len(X), np.float32)
            with torch.no_grad():
                if pre is not None:
                    t1 = time.time()
                    sp = torch.cat([torch.sigmoid(pre(*Mdl.prepare_pre(X[j:j + 2048], Mn[j:j + 2048]))) for j in range(0, len(X), 2048)]).numpy()
                    go = np.nonzero(sp >= pre_thr)[0]; T['first pass'] += time.time() - t1
                t1 = time.time()
                if len(go): s[go] = torch.cat([torch.sigmoid(net(*Mdl.prepare(X[go[j:j + 512]], Mn[go[j:j + 512]]))) for j in range(0, len(go), 512)]).numpy()
                T['classifier'] += time.time() - t1
            nsp[0] += len(X); nsp[1] += len(go)
            # the frame's shift against the empty court, as tv.calib.steady's d: raw = court + d
            dy, dx = P.shift(bg, cur)
            rows.append(np.column_stack([np.full(len(props), c), props[:, :2], s, props[:, 2:5], M, np.full(len(props), -dx), np.full(len(props), -dy)]))
        done += 1
        if done % 200 == 0: print(v, c, '%.2f s/frame' % ((time.time() - t0) / done), flush=True)
    R = np.concatenate(rows) if rows else np.zeros((0, 11))
    np.save(out, R.astype(np.float32))
    print('done', out, len(R), '%.2f s/frame' % ((time.time() - t0) / max(done, 1)))
    print('  per frame: ' + ', '.join('%s %.3f s' % (k, t / max(done, 1)) for k, t in T.items()) + '; %d spots, %d to the classifier' % (nsp[0] / max(done, 1), nsp[1] / max(done, 1)), flush=True)


if __name__ == '__main__':
    v, first, last, step = map(int, sys.argv[1:5])
    main(v, first, last, step, sys.argv[5], sys.argv[6])
