function X = ballCrops(prev, cur, nxt, C, S)
%BALLCROPS  The classifier's input (tv.detect.ballNet): S-by-S crops (default 48) of frames
%   t-K, t, t+K around each candidate (C rows [x y ...], 1-based pixels), edge-padded.
%   prev and nxt must already be lined up with cur (tv.calib.steady).
%   X: S-by-S-by-3-by-3-by-N uint8 (rows, columns, RGB, frame, candidate).
if nargin < 5, S = 48; end
[H, W, ~] = size(cur);
N = size(C, 1);
X = zeros(S, S, 3, 3, N, 'uint8');
F = {prev, cur, nxt};
for i = 1:N
    % same centre as the training crops: pixel round(x) (0-based) at index S/2 (0-based)
    x0 = round(C(i, 1) - 1) - S / 2;  y0 = round(C(i, 2) - 1) - S / 2;
    cols = min(max((x0:x0 + S - 1) + 1, 1), W);  rows = min(max((y0:y0 + S - 1) + 1, 1), H);
    for k = 1:3, X(:, :, :, k, i) = F{k}(rows, cols, :); end
end
end
