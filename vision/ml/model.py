"""The ball classifier: three 48 x 48 crops (t-K, t, t+K) plus the ball's diameter range there.
Small on purpose (about 60k weights): it must run on the PC in MATLAB, and its forward pass is
simple enough to write in plain MATLAB too. Inputs are made independent of the light and the court
colour: each crop is shifted by its own mean colour and scaled by its own spread, and the two
differences (t - (t-K), t - (t+K)) are given explicitly."""
import numpy as np, torch, torch.nn as nn


def prepare(X, M):
    """X: (n, 3, 48, 48, 3) uint8; M: (n, 2) diameter range (px). Returns float tensors."""
    x = torch.from_numpy(X).float() / 255.0                      # n, f, h, w, c
    x = x.permute(0, 1, 4, 2, 3)                                  # n, f, c, h, w
    mid = x[:, 1]
    mu = mid.mean(dim=(2, 3), keepdim=True)                       # per crop, per channel
    sd = mid.std(dim=(1, 2, 3), keepdim=True).clamp_min(0.03)
    frames = (x - mu[:, None]) / sd[:, None]
    d1 = frames[:, 1] - frames[:, 0]; d2 = frames[:, 1] - frames[:, 2]
    inp = torch.cat([frames[:, 0], frames[:, 1], frames[:, 2], d1, d2], dim=1)   # n, 15, h, w
    m = torch.log(torch.from_numpy(M).float().clamp_min(1.0))
    return inp, m


class BallNet(nn.Module):
    def __init__(self):
        super().__init__()
        def block(i, o):
            return nn.Sequential(nn.Conv2d(i, o, 3, padding=1), nn.BatchNorm2d(o), nn.ReLU(inplace=True))
        self.f = nn.Sequential(block(15, 24), block(24, 24), nn.MaxPool2d(2),        # 24
                               block(24, 32), block(32, 32), nn.MaxPool2d(2),        # 12
                               block(32, 48), nn.MaxPool2d(2),                       # 6
                               block(48, 48))
        # the centre matters most: pool the middle 2 x 2 and the whole map
        self.head = nn.Sequential(nn.Linear(48 * 2 + 2, 32), nn.ReLU(inplace=True), nn.Linear(32, 1))

    def forward(self, x, m):
        z = self.f(x)
        c = z[:, :, 2:4, 2:4].mean(dim=(2, 3)); g = z.amax(dim=(2, 3))
        return self.head(torch.cat([c, g, m], dim=1)).squeeze(1)


def augment(X, rng):
    """Light and court-colour changes, flips, a little noise: the classifier must not learn any
    one court's colours or any one light."""
    X = X.astype(np.float32)
    n = len(X)
    # a random colour transform of the whole crop (ball and court together): channel mix + gain
    A = np.eye(3)[None] * rng.uniform(0.7, 1.3, (n, 1, 3)) + rng.normal(0, 0.12, (n, 3, 3))
    X = np.einsum('nfhwc,ndc->nfhwd', X, A.astype(np.float32))
    X = X * rng.uniform(0.6, 1.4, (n, 1, 1, 1, 1)) + rng.uniform(-30, 30, (n, 1, 1, 1, 1))
    g = rng.uniform(0.7, 1.4, (n, 1, 1, 1, 1))                    # gamma
    X = 255.0 * (np.clip(X, 0, 255) / 255.0) ** g
    X += rng.normal(0, rng.uniform(0, 6), (n, 1, 1, 1, 1)) * rng.standard_normal(X.shape).astype(np.float32)
    flip = rng.random(n) < 0.5; X[flip] = X[flip][:, :, :, ::-1]
    flip = rng.random(n) < 0.5; X[flip] = X[flip][:, ::-1]        # time reversed: the ball flies the other way
    return np.clip(X, 0, 255).astype(np.uint8)
