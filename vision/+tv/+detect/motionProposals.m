function [C, tau] = motionProposals(prev, cur, nxt, sizeMap, opts)
%MOTIONPROPOSALS  Small things that move, with no colour test (TV-DET-04 front end, 18 Nov).
%   prev, cur, nxt: frames t-K, t, t+K (H-by-W-by-3 uint8). The neighbours are lined up with t
%   (whole-pixel shift, tv.calib.steady). A pixel moves when it differs from both neighbours even
%   after either is shifted by up to opts.R px: edges and textures that shimmer or sway by a pixel
%   or two (net mesh, fences, tape after steadying) drop out; a ball that moved further does not.
%   The threshold comes from each frame's own noise: the median plus opts.nsig robust deviations
%   of the plain difference over the court of interest, never below opts.floor. Blobs are kept
%   when their size fits a ball there (sizeMap from tv.detect.ballSizeMap): no wider than about
%   two diameters, no longer than nine (motion blur).
%   C: rows [x y area length width strength], x and y 1-based pixels. tau: the threshold used.
%   No value here depends on the court, the light or the ball's colour.
if nargin < 5, opts = struct(); end
d = struct('R', 2, 'nsig', 8, 'floor', 18);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
c = int16(cur);
[a, da] = tv.calib.steady(prev, double(cur));  a = int16(a);
[b, db] = tv.calib.steady(nxt, double(cur));  b = int16(b);
plain = single(min(sum(abs(c - a), 3), sum(abs(c - b), 3)));
% the strip a shift fills from the frame's edge is not motion
ey = max(abs([da(2) db(2)])) + opts.R;  ex = max(abs([da(1) db(1)])) + opts.R;
plain([1:ey, end - ey + 1:end], :) = 0;  plain(:, [1:ex, end - ex + 1:end]) = 0;
mask = sizeMap.mask;
m = plain(mask);  m = m(1:7:end);
med = median(m);  mad = 1.4826 * median(abs(m - med)) + 1e-3;
tau = max(opts.floor, med + opts.nsig * mad);
% the shift-tolerant difference can only be smaller than the plain one, so it can pass the
% threshold only where the plain one does: it is worked out at those pixels and one pixel round
% (closing can add those), which gives the same blobs as working it out everywhere
[H, W] = size(plain);  R = opts.R;  HW = H * W;
M = zeros(H, W, 'single');
idx = find(imdilate(plain > tau, true(3)));
if ~isempty(idx)
    [ys, xs] = ind2sub([H W], idx);
    cv = [c(idx), c(idx + HW), c(idx + 2 * HW)];
    ba = Inf(numel(idx), 1);  bb = ba;
    for dy = -R:R
        yy = min(max(ys - dy, 1), H);
        for dx = -R:R
            j = yy + (min(max(xs - dx, 1), W) - 1) * H;
            ba = min(ba, double(sum(abs(cv - [a(j), a(j + HW), a(j + 2 * HW)]), 2)));
            bb = min(bb, double(sum(abs(cv - [b(j), b(j + HW), b(j + 2 * HW)]), 2)));
        end
    end
    M(idx) = min(ba, bb);
end
M([1:ey, end - ey + 1:end], :) = 0;  M(:, [1:ex, end - ex + 1:end]) = 0;
B = imclose(M > tau, true(3)) & mask;
cc = bwconncomp(B, 8);
C = zeros(0, 6);
for k = 1:cc.NumObjects
    idx = cc.PixelIdxList{k};
    if numel(idx) < 2, continue; end
    [ys, xs] = ind2sub([H W], idx);
    w = double(M(idx));
    x = sum(xs .* w) / sum(w);  y = sum(ys .* w) / sum(w);
    hi = sizeMap.dmax(min(round(y), H), min(round(x), W));
    if hi <= 0, continue; end
    if numel(xs) >= 3
        ev = sort(eig(cov([xs ys]) + 0.25 * eye(2)));
        len = 4 * sqrt(ev(2));  wid = 4 * sqrt(ev(1));
    else
        len = numel(xs);  wid = 1;
    end
    if wid > 2 * hi + 2 || len > 9 * hi + 4 || numel(xs) > pi / 4 * (2 * hi + 2) ^ 2 * 4, continue; end
    C(end+1, :) = [x - 1 + 1, y - 1 + 1, numel(xs), len, wid, max(w)]; %#ok<AGROW>
end
end

