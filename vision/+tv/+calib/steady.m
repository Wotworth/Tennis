function [F, d] = steady(F, bg, maxShift)
%STEADY  Line frames up with the empty court when the camera moved (TV-CAL-14).
%   [F, d] = tv.calib.steady(F, bg) shifts each frame of F (H-by-W-by-3-by-N)
%   by whole pixels so that it lies on bg, the empty court (tv.calib.background).
%   d is N-by-2: each frame's [du dv] against bg, in pixels (content at bg's
%   (u, v) was found at (u + du, v + dv)). Edges uncovered by the shift repeat
%   the frame's border.
%   Why: the empty court is one picture for the whole file, and the detector,
%   the person outline and the court fit all compare frames with it. A phone
%   moved by wind or a loose mount (first real footage, video 1: up to 17 px
%   between clips and 14 px within a clip) makes every edge (net tape, fence
%   rail) look like something moving, and moves the court under the tracks.
%   Method: phase correlation of the grey frame against the grey empty court
%   at half resolution, Hann-windowed; a shift beyond maxShift px (default 40)
%   is taken as no shift (the peak is then not the camera). Static screen
%   overlays must be blanked in F first, or they pull the answer to zero.
%   RETUNE(real footage): maxShift; whole pixels only (no rotation or zoom).
if nargin < 3, maxShift = 40; end
N = size(F, 4);
d = zeros(N, 2);
B = half(grey(bg));
W = hann1(size(B, 1)) * hann1(size(B, 2))';
FB = conj(fft2((B - mean(B(:))) .* W));
lim = maxShift / 2;
for n = 1:N
    A = half(grey(F(:, :, :, n)));
    X = fft2((A - mean(A(:))) .* W) .* FB;
    c = real(ifft2(X ./ max(abs(X), eps)));
    [~, i] = max(c(:));
    [y, x] = ind2sub(size(c), i);
    dy = wrap(y, size(c, 1));  dx = wrap(x, size(c, 2));
    if abs(dy) > lim || abs(dx) > lim, continue; end
    dy = dy + peak(c, y, x, 1);  dx = dx + peak(c, y, x, 2);
    d(n, :) = round(2 * [dx, dy]);
    if any(d(n, :))
        H = size(F, 1);  Wd = size(F, 2);
        rows = min(max((1:H) + d(n, 2), 1), H);  cols = min(max((1:Wd) + d(n, 1), 1), Wd);
        F(:, :, :, n) = F(rows, cols, :, n);
    end
end
end

function g = grey(img)
img = double(img);
g = 0.299 * img(:, :, 1) + 0.587 * img(:, :, 2) + 0.114 * img(:, :, 3);
end

function h = half(g)
H = 2 * floor(size(g, 1) / 2);  W = 2 * floor(size(g, 2) / 2);
g = g(1:H, 1:W);
h = (g(1:2:end, 1:2:end) + g(2:2:end, 1:2:end) + g(1:2:end, 2:2:end) + g(2:2:end, 2:2:end)) / 4;
end

function w = hann1(n)
w = 0.5 - 0.5 * cos(2 * pi * (0:n - 1)' / max(n - 1, 1));
end

function k = wrap(i, n)
k = i - 1;
if k > n / 2, k = k - n; end
end

function s = peak(c, y, x, dim)
% sub-pixel offset of the correlation peak along one direction (parabola through 3 points)
n = size(c, dim);
if dim == 1
    a = c(mod(y - 2, n) + 1, x);  b = c(y, x);  e = c(mod(y, n) + 1, x);
else
    a = c(y, mod(x - 2, n) + 1);  b = c(y, x);  e = c(y, mod(x, n) + 1);
end
den = a - 2 * b + e;
s = 0;
if den < 0, s = max(-0.5, min(0.5, 0.5 * (a - e) / den)); end
end
