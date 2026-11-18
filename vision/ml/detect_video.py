"""Run proposals + classifier over a stretch of a video, reading it straight through.
Writes rows [frame, x, y, score, area, length, width, dmin, dmax] (raw frame pixels) for every
proposal (score included, so the threshold can be chosen later)."""
import numpy as np, subprocess, sys, torch, time, common, proposals as P, gen_data as G, model as Mdl

torch.set_num_threads(1)


def stream(v, first, count):
    p = common.pts(v); t = p[first] - 0.25 / common.FPS
    cmd = ['ffmpeg', '-v', 'error', '-ss', '%.6f' % t, '-i', common.VIDEO[v], '-frames:v', str(count), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    pr = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=10 ** 8)
    n = common.W * common.H * 3
    while True:
        b = pr.stdout.read(n)
        if len(b) < n: break
        yield common.condition(np.frombuffer(b, np.uint8).reshape(common.H, common.W, 3))
    pr.wait()


def main(v, first, last, step, weights, out):
    net = Mdl.BallNet(); net.load_state_dict(torch.load(weights)); net.eval()
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
        props, _ = P.proposals(prev, cur, nxt, dmin, dmax, mask)
        if len(props):
            pa = P.moved(prev, *P.shift(cur, prev)); na = P.moved(nxt, *P.shift(cur, nxt))
            hy = np.minimum(props[:, 1].astype(int) // 2, dmin.shape[0] - 1); hx = np.minimum(props[:, 0].astype(int) // 2, dmin.shape[1] - 1)
            M = np.stack([dmin[hy, hx], dmax[hy, hx]], axis=1).astype(np.float32)
            sc = np.array([G.scale_of(p[4], m[0], m[1]) for p, m in zip(props, M)], np.float32)
            X = np.array([G.crop((pa, cur, na), p[0], p[1], q) for p, q in zip(props, sc)])
            with torch.no_grad():
                s = torch.cat([torch.sigmoid(net(*Mdl.prepare(X[j:j + 512], M[j:j + 512] / sc[j:j + 512, None]))) for j in range(0, len(X), 512)]).numpy()
            # the frame's shift against the empty court, as tv.calib.steady's d: raw = court + d
            dy, dx = P.shift(bg, cur)
            rows.append(np.column_stack([np.full(len(props), c), props[:, :2], s, props[:, 2:5], M, np.full(len(props), -dx), np.full(len(props), -dy)]))
        done += 1
        if done % 200 == 0: print(v, c, '%.2f s/frame' % ((time.time() - t0) / done), flush=True)
    R = np.concatenate(rows) if rows else np.zeros((0, 11))
    np.save(out, R.astype(np.float32))
    print('done', out, len(R), '%.2f s/frame' % ((time.time() - t0) / max(done, 1)))


if __name__ == '__main__':
    v, first, last, step = map(int, sys.argv[1:5])
    main(v, first, last, step, sys.argv[5], sys.argv[6])
