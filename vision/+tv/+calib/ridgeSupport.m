function [score, per] = ridgeSupport(cam, img, opts)
%RIDGESUPPORT  Is there paint under each court line a pose draws? (TV-CAL-11, 17 Nov)
%   Looks at the picture itself, not at the detected line pixels: along each near-half court
%   line in view, at points every few pixels, the brightness across the line must show a thin
%   bright stripe (the centre brighter than both sides, opts.reachPx away) within opts.searchPx
%   of where the pose puts it. Faded paint still makes a faint stripe; bare court makes none.
%   So a pose that draws a line over bare court (the singles/doubles mix-up) scores low on that
%   line even when the line finder missed a faded line under the right pose.
%   score: mean over lines of the share of points with a stripe of at least opts.minContrast
%   grey levels. per: [lineId, nPoints, share].
if nargin < 3, opts = struct(); end
d = struct('reachPx', 6, 'searchPx', 4, 'minContrast', 4, 'minPoints', 15, 'nearHalf', true);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
g = mean(double(img), 3);
[M, id] = tv.calib.modelPoints(0.1);
keep = M(:, 3) == 0;
if opts.nearHalf, keep = keep & sign(M(:, 1)) == sign(cam.pos(1)); end
M = M(keep, :);  id = id(keep);
L = tv.court.lines();
per = zeros(0, 3);
for k = unique(id)'
    s = find(id == k);
    if k > size(L, 1), continue; end
    % the line's direction in the image, from its two ends
    [pe, oke] = tv.camera.project(cam, [L(k, 1:2) 0; L(k, 3:4) 0]);
    [px, ok] = tv.camera.project(cam, M(s, :));
    ok = ok & ~tv.calib.hiddenByNet(cam, M(s, :));
    m = ok & px(:, 1) > opts.reachPx + opts.searchPx + 1 & px(:, 1) < size(g, 2) - opts.reachPx - opts.searchPx - 1 & ...
            px(:, 2) > opts.reachPx + opts.searchPx + 1 & px(:, 2) < size(g, 1) - opts.reachPx - opts.searchPx - 1;
    if nnz(m) < opts.minPoints, continue; end
    dd = pe(2, :) - pe(1, :);
    if ~all(oke) || norm(dd) < 1, dd = px(find(m, 1, 'last'), :) - px(find(m, 1), :); end
    dd = dd / max(norm(dd), eps);  nrm = [-dd(2) dd(1)];
    q = px(m, :);
    best = -inf(size(q, 1), 1);
    for o = -opts.searchPx:opts.searchPx
        c = q + o * nrm;
        v0 = interp2(g, c(:, 1), c(:, 2));
        va = interp2(g, c(:, 1) + opts.reachPx * nrm(1), c(:, 2) + opts.reachPx * nrm(2));
        vb = interp2(g, c(:, 1) - opts.reachPx * nrm(1), c(:, 2) - opts.reachPx * nrm(2));
        best = max(best, min(v0 - va, v0 - vb));
    end
    per(end+1, :) = [k, nnz(m), mean(best >= opts.minContrast)]; %#ok<AGROW>
end
score = 0;
if ~isempty(per), score = mean(per(:, 3)); end
end
