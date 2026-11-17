function C = ballCandidates(F, bg, mask, opts)
%BALLCANDIDATES  Classical ball detector, version 1 (TV-DET-01 to TV-DET-03).
%   F: frames H-by-W-by-3-by-N (uint8); candidates are found in frames
%   2..N-1 (each needs a neighbour on both sides). bg: the empty court
%   (tv.calib.background). mask: where the ball can be (tv.detect.volumeMask).
%   A pixel is a candidate when it is
%     - different from the empty court (so balls lying still, which are in
%       the background, are ignored: TV-DET-02),
%     - different from the previous or the next frame (it moves),
%     - optic yellow (hue, saturation and brightness gate),
%   after each frame's brightness is scaled to the background's, so light
%   flicker does not look like motion. Blobs whose size fits a ball, allowing
%   for motion blur (TV-DET-03), become candidates.
%   Runs on the GPU when there is one, else on the CPU (same code).
%   Returns C, one row per candidate: [frame u v area elongation score],
%   frame 1-based within F, (u, v) the 1-based pixel column and row.
%   First real footage (iPhone, 17 Nov): the ball looks pale, washed out by compression and
%   blur (saturation about 0.18, brightness 0.92, green slightly above red): hue [55 140],
%   minSat 0.12, minVal 0.75 there (cfg.single.detectOpts); and a pale green shirt passes
%   that colour test, so opts.bigPatchArea (px, 0 = off) drops spots that belong to a
%   larger patch of ball colour.
%   RETUNE(real footage): every threshold in opts; the hue range for optic
%   yellow under real light; the size range (opts.minArea, opts.maxArea).
if nargin < 4, opts = struct(); end
d = struct('diffThr', 30, 'motionThr', 18, 'hue', [40 95], 'minSat', 0.35, 'minVal', 0.35, ...
           'minArea', 2, 'maxArea', 400, 'maxElong', 8, 'bigPatchArea', 0);
f = fieldnames(d);
for k = 1:numel(f), if ~isfield(opts, f{k}), opts.(f{k}) = d.(f{k}); end, end
N = size(F, 4);
C = zeros(0, 6);
% work only inside the mask's bounding box (same result, much less work on real frames)
[rr, cc0] = find(mask);
if isempty(rr), return; end
r0 = min(rr);  r1 = max(rr);  c0 = min(cc0);  c1 = max(cc0);
F = F(r0:r1, c0:c1, :, :);  bg = bg(r0:r1, c0:c1, :);  mask = mask(r0:r1, c0:c1);
bgD = tv.util.toDevice(single(bg));
ref = mean(bgD(:));
G = tv.util.toDevice(single(F));
for n = 1:N                                         % brightness normalisation (flicker)
    fr = G(:, :, :, n);
    G(:, :, :, n) = fr * (ref / mean(fr(:)));
end
for n = 2:N - 1
    cur = G(:, :, :, n);
    dBg   = sum(abs(cur - bgD), 3);
    dPrev = sum(abs(cur - G(:, :, :, n - 1)), 3);
    dNext = sum(abs(cur - G(:, :, :, n + 1)), 3);
    mx = max(cur, [], 3);  mn = min(cur, [], 3);
    sat = (mx - mn) ./ max(mx, 1);  val = mx / 255;
    hue = hueDeg(cur, mx, mn);
    yellow = hue >= opts.hue(1) & hue <= opts.hue(2) & sat >= opts.minSat & val >= opts.minVal;
    cand = tv.util.fromDevice(dBg > opts.diffThr & max(dPrev, dNext) > opts.motionThr & yellow) & mask;
    if opts.bigPatchArea > 0
        % a ball is a small spot of its colour; pieces of a larger patch of that colour (a pale
        % green shirt, first real footage) are not balls
        patch = tv.util.fromDevice(dBg > opts.diffThr & yellow);
        big = bwareaopen(imclose(patch, true(5)), opts.bigPatchArea);
        if any(big(:)), cand = cand & ~imdilate(big, true(7)); end
    end
    if ~any(cand(:)), continue; end
    score = tv.util.fromDevice(dBg .* sat);
    cc = bwconncomp(cand, 8);
    for b = 1:cc.NumObjects
        idx = cc.PixelIdxList{b};
        a = numel(idx);
        if a < opts.minArea || a > opts.maxArea, continue; end
        [r, q] = ind2sub(size(cand), idx);
        w = score(idx);  w = w / sum(w);
        u = sum(q .* w);  v = sum(r .* w);
        el = elongation(q, r);
        if el > opts.maxElong, continue; end
        C(end+1, :) = [n, u + c0 - 1, v + r0 - 1, a, el, sum(score(idx))]; %#ok<AGROW>
    end
end
end

function h = hueDeg(img, mx, mn)
% hue in degrees (0-360) from RGB, as in rgb2hsv
r = img(:, :, 1);  g = img(:, :, 2);  b = img(:, :, 3);
d = max(mx - mn, 1e-6);
h = zeros(size(r), 'like', r);
k = mx == r;  h(k) = mod((g(k) - b(k)) ./ d(k), 6);
k = mx == g & ~(mx == r);  h(k) = (b(k) - r(k)) ./ d(k) + 2;
k = mx == b & ~(mx == r) & ~(mx == g);  h(k) = (r(k) - g(k)) ./ d(k) + 4;
h = 60 * h;
end

function e = elongation(q, r)
% ratio of the blob's long axis to its short axis (motion blur makes it > 1)
if numel(q) < 3, e = 1; return; end
S = cov([q r]) + 0.08 * eye(2);
ev = sort(eig(S));
e = sqrt(ev(2) / ev(1));
end
