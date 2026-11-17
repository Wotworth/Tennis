function [trk, added] = follow(trk, readF, bg, mask, span, opts)
%FOLLOW  Look again where each track says the ball should be (Chris, 17 Nov).
%   [trk, added] = tv.track.follow(trk, readF, bg, mask, span, opts) extends the tracks of
%   one clip (tv.track.ball2d) forwards and backwards, and fills the frames inside a
%   track where the ball was not found, by searching a small window around the track's
%   predicted position with looser limits than the detector's search of the whole frame.
%   A faint, blurred or partly hidden ball (at the net, beside a player) is found there
%   without adding false spots elsewhere. Tracks that meet are joined.
%   readF(first, n): frames first..first+n-1 (H-by-W-by-3-by-n), already lined up with
%   the empty court and with overlays blanked. bg: the empty court. mask: where the
%   ball can be. span: [first last] frame of the clip. opts: the detector's options
%   (tv.detect.ballCandidates: hue, minSat, minVal, diffThr, motionThr, maxArea) plus
%     loose      factor on minSat, diffThr and motionThr in the window (0.6)
%     valDrop    lowered minVal in the window (0.15)
%     hueWiden   degrees added to each end of the hue range (10)
%     radius     smallest search radius, px (8); it grows with the ball's speed
%     maxMiss    frames with nothing found before a track's end is given up (3)
%     maxSteps   furthest a track is extended at each end, frames (30)
%     history    points the prediction is fitted to (6; a parabola from 5 points)
%     joinPx     two tracks whose points in shared frames are this close are one (4)
%   added: the number of points found this way.
%   RETUNE(real footage): every value in opts.
if nargin < 6, opts = struct(); end
d = struct('hue', [40 95], 'minSat', 0.35, 'minVal', 0.35, 'diffThr', 30, 'motionThr', 18, 'maxArea', 400, ...
    'loose', 0.6, 'valDrop', 0.15, 'hueWiden', 10, 'radius', 8, 'maxMiss', 3, 'maxSteps', 30, 'history', 6, 'joinPx', 4);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
L = struct('hue', opts.hue + [-1 1] * opts.hueWiden, 'minSat', opts.minSat * opts.loose, ...
    'minVal', opts.minVal - opts.valDrop, 'diffThr', opts.diffThr * opts.loose, 'motionThr', opts.motionThr * opts.loose, ...
    'maxArea', 2 * opts.maxArea);
bg = single(bg);
ref = mean(bg(:));
added = 0;
for i = 1:numel(trk)
    for dirn = [1 -1]
        [trk(i), a] = extend(trk(i), dirn);  added = added + a;
    end
    [trk(i), a] = fillGaps(trk(i));  added = added + a;
end
trk = join(trk, opts.joinPx);

    function [t, a] = extend(t, dirn)
        a = 0;
        f = double(t.frames(:));
        if dirn > 0, f0 = f(end) + 1; f1 = min(span(2) - 1, f(end) + opts.maxSteps);
        else, f0 = f(1) - 1; f1 = max(span(1) + 1, f(1) - opts.maxSteps); end
        if dirn * (f1 - f0) < 0, return; end
        lo = min(f0, f1) - 1;  F = readF(lo, abs(f1 - f0) + 3);
        miss = 0;
        for g = f0:dirn:f1
            [p, sp] = predict(t, g);
            if any(p < 1) || p(1) > size(bg, 2) || p(2) > size(bg, 1), break; end
            q = search(F, g - lo + 1, p, max(opts.radius, 1.5 * sp));
            if isempty(q)
                miss = miss + 1;
                if miss > opts.maxMiss, break; end
                continue
            end
            miss = 0;  t = addPoint(t, g, q);  a = a + 1;
        end
    end

    function [t, a] = fillGaps(t)
        a = 0;
        f = double(t.frames(:));
        gaps = find(diff(f) > 1);
        for j = gaps(:)'
            g0 = f(j) + 1;  g1 = f(j + 1) - 1;
            F = readF(g0 - 1, g1 - g0 + 3);
            for g = g0:g1
                % between the points either side: a parabola through the nearest points
                p = predict(t, g);
                q = search(F, g - g0 + 2, p, opts.radius);
                if ~isempty(q), t = addPoint(t, g, q);  a = a + 1; end
            end
        end
    end

    function [p, sp] = predict(t, g)
        f = double(t.frames(:));
        [~, o] = sort(abs(f - g));
        o = sort(o(1:min(opts.history, numel(f))));
        x = f(o) - g;
        deg = min(2, numel(o) - 1);
        if numel(o) < 5, deg = min(1, deg); end
        p = zeros(1, 2);  sp = 0;
        for c = 1:2
            w = polyfit(x, t.uv(o, c), deg);
            p(c) = polyval(w, 0);
            if deg >= 1, dw = polyder(w); sp = hypot(sp, polyval(dw, 0)); end
        end
    end

    function q = search(F, n, p, r)
        % the ball-like spot nearest p within r in frame n of F (needs frames n-1 and n+1)
        q = [];
        if n < 2 || n > size(F, 4) - 1, return; end
        H = size(bg, 1);  W = size(bg, 2);
        ys = max(1, floor(p(2) - r)):min(H, ceil(p(2) + r));
        xs = max(1, floor(p(1) - r)):min(W, ceil(p(1) + r));
        if isempty(ys) || isempty(xs) || ~any(any(mask(ys, xs))), return; end
        % each frame's brightness scaled to the empty court's, as the detector does (flicker)
        c = crop(n);  b = bg(ys, xs, :);
        dBg = sum(abs(c - b), 3);
        dMo = max(sum(abs(c - crop(n - 1)), 3), sum(abs(c - crop(n + 1)), 3));
        mx = max(c, [], 3);  mn = min(c, [], 3);
        sat = (mx - mn) ./ max(mx, 1);  val = mx / 255;
        h = hueOf(c, mx, mn);
        m = mask(ys, xs) & dBg > L.diffThr & dMo > L.motionThr & sat >= L.minSat & val >= L.minVal ...
            & h >= L.hue(1) & h <= L.hue(2);
        if ~any(m(:)), return; end
        cc = bwconncomp(m, 8);
        best = inf;
        for k = 1:cc.NumObjects
            idx = cc.PixelIdxList{k};
            if numel(idx) > L.maxArea, continue; end
            [rr, qq] = ind2sub(size(m), idx);
            w = dBg(idx) .* sat(idx);  w = w / sum(w);
            u = xs(1) - 1 + sum(qq .* w);  v = ys(1) - 1 + sum(rr .* w);
            dd = hypot(u - p(1), v - p(2));
            if dd <= r && dd < best, best = dd;  q = [u v numel(idx)]; end
        end
        function z = crop(k)
            fr = F(:, :, :, k);
            z = single(fr(ys, xs, :)) * (ref / mean(single(fr(:))));
        end
    end
end

function t = addPoint(t, g, q)
[f, o] = sort([double(t.frames(:)); g]);
uv = [t.uv; q(1:2)];  ar = [t.area(:); q(3)];
t.frames = cast(f, class(t.frames));  t.uv = uv(o, :);  t.area = ar(o);
end

function T = join(T, px)
% tracks that share frames with their points within px of each other are one track
k = 1;
while k <= numel(T)
    merged = false;
    for j = k + 1:numel(T)
        [sf, ia, ib] = intersect(double(T(k).frames), double(T(j).frames));
        if isempty(sf), continue; end
        if median(hypot(T(k).uv(ia, 1) - T(j).uv(ib, 1), T(k).uv(ia, 2) - T(j).uv(ib, 2))) > px, continue; end
        [f, ix] = setdiff(double(T(j).frames), sf);
        for m = 1:numel(f), T(k) = addPoint(T(k), f(m), [T(j).uv(ix(m), :), T(j).area(ix(m))]); end
        T(j) = [];  merged = true;  break
    end
    if ~merged, k = k + 1; end
end
for k = 1:numel(T), T(k).id = k; end
end

function h = hueOf(img, mx, mn)
r = img(:, :, 1);  g = img(:, :, 2);  b = img(:, :, 3);
d = max(mx - mn, 1e-6);
h = zeros(size(r), 'like', r);
k = mx == r;  h(k) = mod((g(k) - b(k)) ./ d(k), 6);
k = mx == g & ~(mx == r);  h(k) = (b(k) - r(k)) ./ d(k) + 2;
k = mx == b & ~(mx == r) & ~(mx == g);  h(k) = (r(k) - g(k)) ./ d(k) + 4;
h = 60 * h;
end
