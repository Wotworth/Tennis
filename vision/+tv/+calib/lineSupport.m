function [score, per] = lineSupport(cam, lineMask, opts)
%LINESUPPORT  How well a fitted pose is backed by paint, line by line (TV-CAL-11, 17 Nov).
%   For each court line (and the net tape) with at least opts.minPoints of its points in
%   the frame, the share of those points within opts.tolPx of a detected line pixel.
%   score: the mean of those shares. A pose that puts a sideline over empty court (the
%   singles/doubles mix-up seen on the first real footage) scores low on that line, even
%   if its other lines land on fences or far courts. Counting matched points or explained
%   pixels did not separate the right pose from that one; this does.
%   per: [lineId, nInFrame, share] per line used.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'tolPx'), opts.tolPx = 3; end
if ~isfield(opts, 'minPoints'), opts.minPoints = 20; end
% opts.nearHalf (default true): only the half of the court on the camera's side of the net,
% and not the net: far lines are squeezed into a few pixels or washed out, and a wrong pose
% can lay its far baseline on the net tape (first real footage, 17 Nov)
if ~isfield(opts, 'nearHalf'), opts.nearHalf = true; end
[M, id] = tv.calib.modelPoints(0.05);
if opts.nearHalf
    keep = sign(M(:, 1)) == sign(cam.pos(1)) & M(:, 3) == 0;
    M = M(keep, :);  id = id(keep);
end
[px, ok] = tv.camera.project(cam, M);
ok = ok & ~tv.calib.hiddenByNet(cam, M);
D = bwdist(lineMask);
d = inf(size(M, 1), 1);
d(ok) = interp2(D, px(ok, 1), px(ok, 2), 'linear', Inf);
per = zeros(0, 3);
for k = unique(id)'
    s = id == k & ok;
    if nnz(s) < opts.minPoints, continue; end
    per(end+1, :) = [k, nnz(s), mean(d(s) <= opts.tolPx)]; %#ok<AGROW>
end
score = 0;
if ~isempty(per), score = mean(per(:, 3)); end
end
