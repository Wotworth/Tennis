"""Weights for MATLAB (tv.detect.loadBallNet): batch norm folded into each convolution; plain JSON.
Also a check case: 6 crops and the PyTorch probabilities."""
import json, sys, numpy as np, torch, model as Mdl


def fold(conv, bn):
    W = conv.weight.detach().numpy(); b = conv.bias.detach().numpy()
    g = bn.weight.detach().numpy() / np.sqrt(bn.running_var.numpy() + bn.eps)
    return W * g[:, None, None, None], (b - bn.running_mean.numpy()) * g + bn.bias.detach().numpy()


def main(weights, out, check=None):
    net = Mdl.BallNet()
    if weights != 'random': net.load_state_dict(torch.load(weights))
    else:
        torch.manual_seed(0)
        for m in net.modules():
            if isinstance(m, torch.nn.BatchNorm2d):
                m.running_mean.uniform_(-0.2, 0.2); m.running_var.uniform_(0.5, 1.5); m.weight.data.uniform_(0.5, 1.5); m.bias.data.uniform_(-0.2, 0.2)
    net.eval()
    convs = []
    seq = list(net.f)
    for k, layer in enumerate(seq):
        if isinstance(layer, torch.nn.Sequential):
            W, b = fold(layer[0], layer[1])
            pool = k + 1 < len(seq) and isinstance(seq[k + 1], torch.nn.MaxPool2d)
            # MATLAB order: 3 x 3 x cin x cout, W(dy+1, dx+1, ci, co) = torch W[co, ci, dy, dx]
            convs.append({'W': np.transpose(W, (2, 3, 1, 0)).tolist(), 'b': b.tolist(), 'pool': bool(pool)})
    fc1, fc2 = net.head[0], net.head[2]
    J = {'note': 'Ball classifier (TV-DET-04), trained on Chris\'s footage with drawn balls; batch norm folded.',
         'conv': convs, 'fc1': {'W': fc1.weight.detach().numpy().tolist(), 'b': fc1.bias.detach().numpy().tolist()},
         'fc2': {'W': fc2.weight.detach().numpy().tolist(), 'b': fc2.bias.detach().numpy().tolist()}}
    json.dump(J, open(out, 'w'))
    if check:
        rng = np.random.default_rng(3)
        X = rng.integers(0, 255, (6, 3, 48, 48, 3), dtype=np.uint8)
        X[:, 1, 20:26, 20:26] = 230                                # a pale blob in the middle frame
        M = np.array([[3, 9], [4, 12], [3, 6], [5, 20], [3, 8], [2, 5]], np.float32)
        with torch.no_grad():
            p = torch.sigmoid(net(*Mdl.prepare(X, M))).numpy()
        json.dump({'X': X.tolist(), 'M': M.tolist(), 'p': p.tolist()}, open(check, 'w'))
        print('check', p)


if __name__ == '__main__':
    main(*sys.argv[1:])
