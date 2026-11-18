function X = ballCrops(prev, cur, nxt, C, S, scale)
%BALLCROPS  The classifier's input (tv.detect.ballNet): S-by-S cuts (default 48) of frames
%   t-K, t, t+K around each candidate (C rows [x y ...], 1-based pixels).
%   prev and nxt must already be lined up with cur (tv.calib.steady).
%   With scale (N-by-1, the ball's likely diameter at each spot, tv.detect.ballScale): each cut
%   is a square of S/6 diameters (24 to 192 px) resampled to S-by-S, so a ball is 6 px across in
%   it whatever the camera, its resolution or the distance (round 4, 18 Nov). Bilinear,
%   edge-clamped, averaged over 2-by-2 samples per output pixel when shrinking; the Python twin
%   (vision/ml/gen_data.py, resample) does exactly the same.
%   Without scale: the frame's own pixels around round(x), edge-padded (rounds 1-3).
%   X: S-by-S-by-3-by-3-by-N uint8 (rows, columns, RGB, frame, candidate).
if nargin < 5 || isempty(S), S = 48; end
[H, W, ~] = size(cur);
N = size(C, 1);
X = zeros(S, S, 3, 3, N, 'uint8');
F = {prev, cur, nxt};
if nargin >= 6 && ~isempty(scale)
    for i = 1:N
        side = min(max(scale(i) * S / 6, 24), 192);
        for k = 1:3, X(:, :, :, k, i) = uint8(min(max(floor(resample(F{k}, C(i, 1), C(i, 2), side, S) + 0.5), 0), 255)); end
    end
    return
end
for i = 1:N
    % same centre as the training crops: pixel round(x) (0-based) at index S/2 (0-based)
    x0 = round(C(i, 1) - 1) - S / 2;  y0 = round(C(i, 2) - 1) - S / 2;
    cols = min(max((x0:x0 + S - 1) + 1, 1), W);  rows = min(max((y0:y0 + S - 1) + 1, 1), H);
    for k = 1:3, X(:, :, :, k, i) = F{k}(rows, cols, :); end
end
end

function out = resample(img, cx, cy, side, n)
% the square of `side` px centred on (cx, cy) (1-based pixel centres), resampled to n-by-n
ss = 1 + (side > n);  g = n * ss;
o = (((0:g - 1) + 0.5) / g - 0.5) * side;
[h, w, ~] = size(img);
u = min(max(cx + o, 1), w);  v = min(max(cy + o, 1), h);
u0 = floor(u);  v0 = floor(v);  u1 = min(u0 + 1, w);  v1 = min(v0 + 1, h);
fu = reshape(u - u0, 1, []);  fv = reshape(v - v0, [], 1);
% (only the pixels needed are converted to double, not the whole frame)
out = (double(img(v0, u0, :)) .* (1 - fu) + double(img(v0, u1, :)) .* fu) .* (1 - fv) ...
    + (double(img(v1, u0, :)) .* (1 - fu) + double(img(v1, u1, :)) .* fu) .* fv;
if ss > 1, out = reshape(mean(mean(reshape(out, ss, n, ss, n, []), 1), 3), n, n, []); end
end
