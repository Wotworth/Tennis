"""The ball classifier (round 4, 18 Nov): three 48 x 48 cuts (t-K, t, t+K), each scaled so a ball
there would be 6 px across, plus how that size compares with what the camera's geometry allows.
Small on purpose (about 60k weights): it must run on the PC in MATLAB, and its forward pass is
simple enough to write in plain MATLAB too.
It is given no colour at all: three brightness images (shifted by the cut's own mean and scaled by
its own spread, so the light does not matter) and two motion images (how much each pixel changed
against t-K and t+K, in any colour channel). In training, light and dark are swapped at random,
so a dark ball on a pale court is the same to it as a pale ball on a dark one."""
import numpy as np, torch, torch.nn as nn


def prepare(X, M):
    """X: (n, 3, 48, 48, 3) uint8; M: (n, 2) the geometry's diameter range over the cut's scale.
    Returns float tensors (n, 5, 48, 48) and (n, 2)."""
    x = torch.from_numpy(X).float() / 255.0                      # n, f, h, w, c
    grey = x.mean(dim=4)                                          # n, f, h, w
    mid = grey[:, 1]
    mu = mid.mean(dim=(1, 2), keepdim=True)
    sd = mid.std(dim=(1, 2), keepdim=True).clamp_min(0.03)
    frames = (grey - mu[:, None]) / sd[:, None]
    d1 = (x[:, 1] - x[:, 0]).abs().mean(dim=3) / sd; d2 = (x[:, 1] - x[:, 2]).abs().mean(dim=3) / sd
    inp = torch.cat([frames, d1[:, None], d2[:, None]], dim=1)   # n, 5, h, w
    m = torch.log(torch.from_numpy(M).float().clamp(0.05, 20.0))
    return inp, m


class BallNet(nn.Module):
    def __init__(self):
        super().__init__()
        def block(i, o):
            return nn.Sequential(nn.Conv2d(i, o, 3, padding=1), nn.BatchNorm2d(o), nn.ReLU(inplace=True))
        self.f = nn.Sequential(block(5, 24), block(24, 24), nn.MaxPool2d(2),        # 24
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
    inv = rng.random(n) < 0.5; X[inv] = 255.0 - X[inv]             # light and dark swapped: a dark ball on a pale court
    flip = rng.random(n) < 0.5; X[flip] = X[flip][:, :, :, ::-1]
    flip = rng.random(n) < 0.5; X[flip] = X[flip][:, ::-1]        # time reversed: the ball flies the other way
    return np.clip(X, 0, 255).astype(np.uint8)
