function p = ballNet(net, X, M)
%BALLNET  The learned ball classifier (TV-DET-04, brought forward 18 Nov): ball probability for
%   each candidate spot.
%   X: 48-by-48-by-3-by-3-by-N uint8: three crops per spot (frames t-K, t, t+K, lined up with t),
%   rows-by-columns-by-RGB-by-frame-by-spot. M: N-by-2: the ball's diameter range there (px, from
%   the camera fit). net: the weights (tv.detect.loadBallNet), batch norm folded into the
%   convolutions. Plain MATLAB, no toolbox: the same numbers as the PyTorch model it was
%   trained as (tests/ballNetTest.m checks them on a saved case).
%   Inputs are made independent of the light and the court colour first: each crop is shifted by
%   its own mean colour and scaled by its own spread, and the two differences (t - (t-K) and
%   t - (t+K)) are given explicitly.
N = size(X, 5);
x = double(X) / 255;                                        % h w c f n
mid = x(:, :, :, 2, :);
mu = mean(mean(mid, 1), 2);                                 % 1 1 c 1 n: per spot and channel
m2 = reshape(mid, [], N);
sd = max(std(m2, 0, 1), 0.03);                              % per spot, over all its pixels and channels
f = (x - mu) ./ reshape(sd, 1, 1, 1, 1, N);
A = cat(3, f(:, :, :, 1, :), f(:, :, :, 2, :), f(:, :, :, 3, :), ...
    f(:, :, :, 2, :) - f(:, :, :, 1, :), f(:, :, :, 2, :) - f(:, :, :, 3, :));
A = reshape(A, 48, 48, 15, N);
for k = 1:numel(net.conv)
    A = max(conv3(A, net.conv(k).W, net.conv(k).b), 0);
    if net.conv(k).pool, A = pool2(A); end
end
% head: mean of the middle 2 x 2, max over the map, and log of the diameter range
c = reshape(mean(mean(A(3:4, 3:4, :, :), 1), 2), [], N);
g = reshape(max(max(A, [], 1), [], 2), [], N);
z = [c; g; log(max(double(M'), 1))];
h = max(net.fc1.W * z + net.fc1.b, 0);
o = net.fc2.W * h + net.fc2.b;
p = (1 ./ (1 + exp(-o)))';
end

function B = conv3(A, W, b)
% 3 x 3 convolution with zero padding: A h-by-w-by-cin-by-n, W 3-by-3-by-cin-by-cout (as torch,
% cross-correlation), by im2col and one matrix product
[h, w, ci, n] = size(A);
P = zeros(h + 2, w + 2, ci, n);  P(2:end-1, 2:end-1, :, :) = A;
cols = zeros(h * w * n, 9 * ci);
k = 0;
for dx = 0:2
    for dy = 0:2
        k = k + 1;
        s = P(1 + dy:h + dy, 1 + dx:w + dx, :, :);         % h w ci n
        cols(:, (k - 1) * ci + (1:ci)) = reshape(permute(s, [1 2 4 3]), [], ci);
    end
end
Wm = reshape(permute(W, [3 1 2 4]), 9 * ci, []);          % (ci, dy, dx) to match cols
B = permute(reshape(cols * Wm + b(:)', h, w, n, []), [1 2 4 3]);
end

function B = pool2(A)
[h, w, c, n] = size(A);
B = reshape(max(max(reshape(A, 2, h / 2, 2, w / 2, c, n), [], 1), [], 3), h / 2, w / 2, c, n);
end
