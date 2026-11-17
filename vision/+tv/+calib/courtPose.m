function [cam, report] = courtPose(bg, cam0, opts)
%COURTPOSE  Camera position and aim from the court lines in one background image.
%   TV-CAL-10/11: match the known court model to the white line pixels.
%   Each model point (every 5 cm along each line, plus the net tape) is
%   projected with the trial pose; its residual is the distance, in pixels,
%   to the nearest detected line pixel (a distance map, so no point-to-point
%   matching is needed). Least squares (lsqnonlin) over the camera's
%   position and three angles, first with a loose cap on each residual, then
%   a tight one so only lines that truly match count.
%   cam0: starting camera (lens known; pose from the placement plan or
%   config, within about 0.5 m and 3 degrees).
%   report.rmsPx: line reprojection error over matched points (TV-CAL-13
%   target 1.0 px); report.inliers: how many model points matched.
%   Deviation from the spec's estworldpose start: the distance-map match
%   needs no line intersections, which are hard to find where the far court
%   is squeezed to a few pixels; logged in DECISIONS.md.
%   RETUNE(real footage): caps (12 then 3 px) and the coarse search range.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'searchDeg'), opts.searchDeg = 3; end
% the fit stays within opts.maxMove metres of the start, and above opts.minHeight: unbounded, a
% camera far away squeezes the whole court onto a few line pixels and scores well (17 Nov, first
% real footage)
if ~isfield(opts, 'maxMove'), opts.maxMove = 5; end
if ~isfield(opts, 'minHeight'), opts.minHeight = 0.3; end
% opts.fitFocal: also fit the lens's focal length (a scale, within +/-40%), for a camera whose
% lens is not calibrated (a phone; TV-CAL-01's checkerboard calibration replaces it for the GoPros)
if ~isfield(opts, 'fitFocal'), opts.fitFocal = false; end
if ~isfield(opts, 'lineOpts'), opts.lineOpts = struct(); end
[mask, ~] = tv.calib.linePixels(bg, opts.lineOpts);   % lineOpts: real-footage line settings (tv.calib.linePixels)
D = bwdist(mask);
M = tv.calib.modelPoints(0.05);
% keep the model points the starting pose puts in the frame
[~, ok0] = tv.camera.project(cam0, M);
ok0 = ok0 & ~tv.calib.hiddenByNet(cam0, M);    % behind the net from here: the tape would pass for it
M = M(ok0, :);
p0 = [cam0.pos, 0, 0, 0];                      % position + small rotation (deg)
if opts.fitFocal, p0(7) = 0; end               % log focal scale

% 1. coarse search over yaw and pitch, loose cap
best = p0;  bestCost = cost(p0, 12);
for dy = -opts.searchDeg:1:opts.searchDeg
    for dp = -opts.searchDeg:1:opts.searchDeg
        p = p0;  p(4:5) = [dy dp];
        cst = cost(p, 12);
        if cst < bestCost, best = p; bestCost = cst; end
    end
end
% 2. and 3. least squares, loose then tight
% finite-difference steps of 1 mm / 0.001 deg: the distance map is flat at much finer steps
o = optimset('Display', 'off', 'TolFun', 1e-10, 'TolX', 1e-9, 'MaxIter', 200, 'DiffMinChange', 1e-3);
lb = [cam0.pos - opts.maxMove, -30 -30 -30];  ub = [cam0.pos + opts.maxMove, 30 30 30];
if opts.fitFocal, lb(7) = log(0.6); ub(7) = log(1.4); end
lb(3) = max(lb(3), opts.minHeight);  ub(3) = max(ub(3), lb(3) + 0.1);
best = min(max(best, lb), ub);
p = lsqnonlin(@(p) res(p, 12), best, lb, ub, o);
p = lsqnonlin(@(p) res(p, 3), p, lb, ub, o);
p = p(:)';  cam = apply(p);
r = res(p, Inf);
in = r < 3;
report.rmsPx = sqrt(mean(r(in).^2));
report.inliers = nnz(in);
report.points = numel(r);
report.params = p;

    function c = apply(p)
        p = p(:)';  c = cam0;  c.pos = p(1:3);
        if numel(p) >= 7, c.lens = scaleFocal(cam0.lens, exp(p(7))); end
        Rd = rotation(p(4:6));
        c.R = (cam0.R' * Rd)';          % small rotation about the camera's own axes
    end
    function r = res(p, cap)
        c = apply(p);
        [px, ok] = tv.camera.project(c, M);
        r = cap * ones(size(M, 1), 1);
        if any(ok)
            r(ok) = min(cap, interp2(D, px(ok, 1), px(ok, 2), 'linear', cap));
        end
    end
    function s = cost(p, cap)
        s = sum(res(p, cap).^2);
    end
end

function R = rotation(a)
% small rotations (deg) about the camera's down (yaw), right (pitch) and forward (roll) axes
a = deg2rad(a);
Ry = [cos(a(1)) 0 -sin(a(1)); 0 1 0; sin(a(1)) 0 cos(a(1))];
Rp = [1 0 0; 0 cos(a(2)) sin(a(2)); 0 -sin(a(2)) cos(a(2))];
Rr = [cos(a(3)) sin(a(3)) 0; -sin(a(3)) cos(a(3)) 0; 0 0 1];
R = Ry * Rp * Rr;
end

function lens = scaleFocal(lens, k)
switch lens.type
    case 'rectilinear', lens.F = lens.F * k;
    case 'radial',      lens.c1 = lens.c1 * k;  lens.c3 = lens.c3 * k;
end
end
