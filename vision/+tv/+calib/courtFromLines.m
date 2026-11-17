function [cam, report] = courtFromLines(bg, lens, opts)
%COURTFROMLINES  Camera pose (and, for an uncalibrated lens, its focal length) from the
%   court's line pattern (TV-CAL-10/11: "fit the known court model by matching line
%   intersections"; Chris 17 Nov: must not be fooled by pickleball lines, white or coloured).
%   1. Straight lines in the background frame (tv.calib.linePixels, tv.calib.imageLines).
%   2. Lines across the view (baselines, service lines) and along it (sidelines, centre
%      line), by angle. Every pair of across lines with every pair of along lines gives four
%      crossings; each is matched to four crossings of the tennis court (each ordered pair of
%      court lines across, each ordered pair along), giving a ground-plane homography.
%   3. Each homography is scored by the near half's lines, one by one: the share of each
%      line's points that lie on detected paint (tv.calib.lineSupport's rule). A pattern
%      that is not the tennis court (a pickleball court, the neighbour's lines) leaves some
%      tennis line over bare court and scores low, whatever the tape's colour.
%   4. The best few become poses (focal length from the homography when opts.fitFocal),
%      refined on all line pixels (tv.calib.courtPose), and the best refined pose wins.
%   Assumes the camera looks along the court from behind or beside the -x baseline; the
%   other end is the same court turned half round (tv.calib.rotate180 resolves it later).
%   opts.lineOpts: tv.calib.linePixels settings; opts.fitFocal: the lens's focal length is
%   unknown (a phone); lens must then be rectilinear. report: rmsPx, inliers, support,
%   hfovDeg, nLines, nHypotheses, candidates.
if nargin < 3, opts = struct(); end
d0 = struct('lineOpts', struct(), 'fitFocal', false, 'acrossDeg', 15, 'keepPerClass', 8, ...
            'keepPoses', 12, 'tolPx', 3);
fn = fieldnames(d0);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d0.(fn{k}); end, end
if opts.fitFocal && ~strcmp(lens.type, 'rectilinear')
    error('tv:calib:focal', 'Fitting the focal length needs a rectilinear lens.');
end
W = lens.widthPx;  H = lens.heightPx;
[mask, ~] = tv.calib.linePixels(bg, opts.lineOpts);
D = bwdist(mask);
% working plane: centred pixels for a rectilinear lens; ideal pinhole (f = 1) otherwise
if strcmp(lens.type, 'rectilinear') 
    toPlane = @(q) [q(:, 1) - (W + 1) / 2, q(:, 2) - (H + 1) / 2];
    fPix = lens.F * W / 2;
else
    toPlane = @(q) undistort(lens, q, W, H);
    fPix = 1;
end
L = tv.calib.imageLines(mask, struct('toPlane', toPlane));
ang = arrayfun(@(l) abs(atan2d(l.d(2), l.d(1))), L);
ang = min(ang, 180 - ang);
across = L(ang < opts.acrossDeg);  along = L(ang >= opts.acrossDeg);
across = across(1:min(end, opts.keepPerClass));  along = along(1:min(end, opts.keepPerClass));
% order: across lines bottom to top (near to far), along lines left to right
across = across(argsortBy(arrayfun(@(l) -yAt(l, 0), across)));
along = along(argsortBy(arrayfun(@(l) xAt(l, median(arrayfun(@(a) yAt(a, 0), across))), along)));
c = tv.court.constants();
mx = [-c.halfLength, -c.serviceLine, c.serviceLine, c.halfLength];       % near to far
my = [c.halfDoubles, c.halfSingles, 0, -c.halfSingles, -c.halfDoubles];   % left to right (camera at -x)
% near-half model points by line, for scoring
[Mp, id] = tv.calib.modelPoints(0.1);
nearPts = Mp(:, 1) < 0 & Mp(:, 3) == 0;  Mp = Mp(nearPts, 1:2);  id = id(nearPts);
ids = unique(id);
hyp = zeros(0, 10);   % score, then H(:)' (9)
for a1 = 1:numel(across), for a2 = a1 + 1:numel(across)
for b1 = 1:numel(along), for b2 = b1 + 1:numel(along)
    U = [cross2(across(a1), along(b1)); cross2(across(a1), along(b2)); ...
         cross2(across(a2), along(b1)); cross2(across(a2), along(b2))];
    if any(~isfinite(U(:))), continue; end
    for i1 = 1:4, for i2 = i1 + 1:4
    for j1 = 1:5, for j2 = j1 + 1:5
        X = [mx(i1) my(j1); mx(i1) my(j2); mx(i2) my(j1); mx(i2) my(j2)];
        Hm = homography(X, U);
        if isempty(Hm), continue; end
        % only patterns a real camera could see (a focal length in range, camera above ground)
        [~, okc] = poseFromH(Hm, lens, fPix, opts.fitFocal, W);
        if ~okc, [~, okc] = poseFromH(Hm * diag([1 -1 1]), lens, fPix, opts.fitFocal, W); end
        if ~okc, continue; end
        s = support(Hm);
        if s > 0.3, hyp(end+1, :) = [s, Hm(:)']; end %#ok<AGROW>
    end, end
    end, end
end, end
end, end
% one line across with three along (sidelines, centre line): the along lines meet at the
% vanishing point of the court's length, the fourth match (17 Nov: on Chris's court the
% service line is faded and the far baseline washed out, so the near baseline is the only
% clear line across)
for a1 = 1:numel(across)
for b1 = 1:numel(along), for b2 = b1 + 1:numel(along), for b3 = b2 + 1:numel(along)
    [vp, okv] = meetPoint(along([b1 b2 b3]));
    if ~okv, continue; end
    U = [cross2(across(a1), along(b1)); cross2(across(a1), along(b2)); cross2(across(a1), along(b3))];
    if any(~isfinite(U(:))), continue; end
    for i1 = 1:4
    for j = nchoosek(1:5, 3)'
        Xh = [mx(i1) my(j(1)) 1; mx(i1) my(j(2)) 1; mx(i1) my(j(3)) 1; 1 0 0];
        Uh = [U, ones(3, 1); vp];
        Hm = homographyH(Xh, Uh);
        if isempty(Hm), continue; end
        [~, okc] = poseFromH(Hm, lens, fPix, opts.fitFocal, W);
        if ~okc, [~, okc] = poseFromH(Hm * diag([1 -1 1]), lens, fPix, opts.fitFocal, W); end
        if ~okc, continue; end
        sc = support(Hm);
        if sc > 0.3, hyp(end+1, :) = [sc, Hm(:)']; end %#ok<AGROW>
    end
    end
end, end, end
end
report.nLines = numel(L);  report.nAcross = numel(across);  report.nAlong = numel(along);  report.nHypotheses = size(hyp, 1);
report.lines = L;
if isempty(hyp), error('tv:calib:noCourt', 'No court line pattern found.'); end
[~, o] = sort(hyp(:, 1), 'descend');
best = -Inf;  cam = [];  cands = zeros(0, 6);  report.rejected = {};
for i = o(1:min(end, opts.keepPoses))'
    Hm = reshape(hyp(i, 2:10), 3, 3);
    % the court is the same mirrored left to right, so a mirrored match is the same court
    [c0, ok, why] = poseFromH(Hm, lens, fPix, opts.fitFocal, W);
    if ~ok, [c0, ok, why] = poseFromH(Hm * diag([1 -1 1]), lens, fPix, opts.fitFocal, W); end
    if ~ok, report.rejected{end+1} = why; continue; end
    [cR, rep] = tv.calib.courtPose(bg, c0, struct('searchDeg', 1, 'maxMove', 2, 'lineOpts', opts.lineOpts, ...
        'fitFocal', opts.fitFocal));
    sup = tv.calib.lineSupport(cR, mask, struct('tolPx', opts.tolPx));
    cands(end+1, :) = [cR.pos, sup, rep.rmsPx, hyp(i, 1)]; %#ok<AGROW>
    if sup > best, best = sup; cam = cR; report.rmsPx = rep.rmsPx; report.inliers = rep.inliers; end
end
if isempty(cam), error('tv:calib:noCourt', 'No pose from the court line pattern (%s).', strjoin(unique(report.rejected), '; ')); end
report.support = best;
report.hfovDeg = NaN;
if strcmp(cam.lens.type, 'rectilinear'), report.hfovDeg = 2 * atand(1 / cam.lens.F); end
report.candidates = cands;     % [x y z support rmsPx homographyScore]

    function s = support(Hm)
        p = [Mp, ones(size(Mp, 1), 1)] * Hm';
        ok = p(:, 3) > 0;
        q = p(:, 1:2) ./ p(:, 3);
        if strcmp(lens.type, 'rectilinear')
            px = [q(:, 1) + (W + 1) / 2, q(:, 2) + (H + 1) / 2];
        else
            px = redistort(lens, q, W, H);
        end
        ok = ok & px(:, 1) >= 1 & px(:, 1) <= W & px(:, 2) >= 1 & px(:, 2) <= H;
        dd = inf(size(ok));
        dd(ok) = interp2(D, px(ok, 1), px(ok, 2), 'linear', Inf);
        sh = [];
        for kk = ids'
            m = id == kk & ok;
            if nnz(m) >= 10, sh(end+1) = mean(dd(m) <= opts.tolPx); end %#ok<AGROW>
        end
        s = 0;
        if numel(sh) >= 3, s = mean(sh); end
    end
end

function o = argsortBy(v)
[~, o] = sort(v);
end

function y = yAt(l, x)
% the line's y at x (working plane); lines near vertical give Inf
if abs(l.n(2)) < 1e-9, y = Inf; else, y = (l.c - l.n(1) * x) / l.n(2); end
end

function x = xAt(l, y)
if abs(l.n(1)) < 1e-9, x = Inf; else, x = (l.c - l.n(2) * y) / l.n(1); end
end

function p = cross2(a, b)
A = [a.n; b.n];
if abs(det(A)) < 1e-9, p = [NaN NaN]; return; end
p = (A \ [a.c; b.c])';
end

function Hm = homography(X, U)
% DLT, plane (x, y) -> working plane (u, v)
A = zeros(8, 9);
for i = 1:4
    x = X(i, 1);  y = X(i, 2);  u = U(i, 1);  v = U(i, 2);
    A(2 * i - 1, :) = [x y 1 0 0 0 -u * x -u * y -u];
    A(2 * i, :)     = [0 0 0 x y 1 -v * x -v * y -v];
end
[~, S, V] = svd(A);
if S(8, 8) < 1e-9 * S(1, 1), Hm = []; return; end
Hm = reshape(V(:, 9), 3, 3)';
end

function [cam, ok, why] = poseFromH(Hm, lens, fPix, fitFocal, W)
ok = false;  cam = [];  why = '';
h1 = Hm(:, 1);  h2 = Hm(:, 2);
if fitFocal
    f2 = [];
    a = -(h1(1) * h2(1) + h1(2) * h2(2)) / (h1(3) * h2(3));
    if isfinite(a) && a > 0, f2(end+1) = a; end
    b = (h1(1)^2 + h1(2)^2 - h2(1)^2 - h2(2)^2) / (h2(3)^2 - h1(3)^2);
    if isfinite(b) && b > 0, f2(end+1) = b; end
    if isempty(f2), why = 'no focal length'; return; end
    fPix = sqrt(mean(f2));
    if fPix < 0.3 * W / 2 || fPix > 6 * W / 2, why = sprintf('focal %.0f px', fPix); return; end     % 160 deg to 19 deg wide
    lens.F = fPix / (W / 2);
end
K = diag([fPix fPix 1]);
M = K \ Hm;
lam = 1 / norm(M(:, 1));
r1 = lam * M(:, 1);  r2 = lam * M(:, 2);  t = lam * M(:, 3);
if t(3) < 0, r1 = -r1; r2 = -r2; t = -t; end
R = [r1, r2, cross(r1, r2)];
[U, ~, V] = svd(R);  R = U * V';
if det(R) < 0, why = 'mirrored'; return; end
C = (-R' * t)';
if C(3) <= 0.2, why = sprintf('camera height %.1f m', C(3)); return; end
cam = tv.camera.make(lens, C, 0, 0, 0);
cam.R = R;               % rows: right, down, forward in court axes
ok = true;
end

function q = undistort(lens, px, W, H)
[d, ~] = tv.lens.unproject(lens, px(:, 1) - (W + 1) / 2, px(:, 2) - (H + 1) / 2);
q = d(:, 1:2) ./ d(:, 3);
end

function px = redistort(lens, q, W, H)
[u, v] = tv.lens.toPixels(lens, q(:, 1), q(:, 2), ones(size(q, 1), 1));
px = [u + (W + 1) / 2, v + (H + 1) / 2];
end

function [vp, ok] = meetPoint(Ls)
% least-squares common point of three lines (homogeneous, may be at infinity); ok when they
% truly meet (each line's normal residual small against the spread)
A = [vertcat(Ls.n), -vertcat(Ls.c)];
A = A ./ vecnorm(A(:, 1:2), 2, 2);
[~, S, V] = svd(A);
vp = V(:, 3)';
ok = S(3, 3) < 1e-3 * S(1, 1) || S(3, 3) < 2e-3;
if abs(vp(3)) > 1e-12, vp = vp / vp(3); end
end

function Hm = homographyH(X, U)
% DLT from homogeneous correspondences X (plane) -> U (working plane), rows [x y w]
A = zeros(2 * size(X, 1), 9);
for i = 1:size(X, 1)
    x = X(i, :);  u = U(i, :);
    A(2 * i - 1, :) = [zeros(1, 3), -u(3) * x, u(2) * x];
    A(2 * i, :)     = [u(3) * x, zeros(1, 3), -u(1) * x];
end
[~, S, V] = svd(A);
if S(8, 8) < 1e-9 * S(1, 1), Hm = []; return; end
Hm = reshape(V(:, 9), 3, 3)';
end
