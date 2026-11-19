function [cam, report] = fromCorners(bg, lens, taps, opts)
%FROMCORNERS  A camera's pose from the four corners of the doubles court, tapped on its picture.
%   The fallback when the court-line fit is doubtful (TV-CAL-11; Chris, 19 Nov: tap the four
%   court corners in the app so a session isn't lost).
%   [cam, report] = tv.calib.fromCorners(bg, lens, taps)
%   bg: the empty court (tv.calib.background). lens: this camera's lens at the picture's size.
%   taps: 4-by-2 pixel positions [u v] (1-based, the picture's own pixels) of the four corners
%   where the baselines meet the doubles sidelines, in any order.
%   1. The taps are put in order round the court, and each way of matching them to the court's
%      corners in that order is tried: the pose that puts the corners on the taps through the
%      lens model (a plane-to-picture fit, then least squares on the pixel error). The court is
%      a rectangle, so its half-turn twin fits exactly as well; the one on the y <= 0 side is
%      returned, as tv.calib.searchPose does (the second camera settles it,
%      tv.calib.resolveSymmetry). A match that swaps the court's long and short sides leaves
%      the corners well off the taps and loses.
%   2. A finger is good to a few pixels, so the pose is then refined on the court's line pixels
%      (tv.calib.courtPose), held within opts.maxMove m (0.7) of the tapped pose and opts.searchDeg
%      degrees (2): less than the court's look-alike shifts (an alley is 1.37 m), so the lines can
%      sharpen the pose but not pull it onto the wrong ones. The refined pose is kept when paint
%      backs its lines about as well as the tapped pose's or better (tv.calib.lineSupport, within
%      opts.supportSlack); otherwise the tapped pose stands (lines too faint to help). A second
%      round from the refined pose is kept when it matches more line points.
%   report: tapRmsPx (the corners against the taps, final pose), rmsPx and inliers (line fit),
%   support, refined (the line refinement was kept), source = 'corners'.
%   opts.lineOpts: tv.calib.linePixels settings (tv.calib.lineOptsFor).
%   RETUNE(real footage): maxMove, searchDeg and supportSlack, once real taps on real pictures exist.
if nargin < 4, opts = struct(); end
d = struct('maxMove', 0.7, 'searchDeg', 2, 'supportSlack', 0.05, 'lineOpts', struct(), 'minHeight', 0.5, 'maxHeight', 15, 'maxRange', 45);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
taps = double(taps);
if ~isequal(size(taps), [4 2]), error('tv:calib:corners', 'Four tapped corners are needed, one [u v] per row.'); end
c = tv.court.constants();
X = [-c.halfLength -c.halfDoubles; -c.halfLength c.halfDoubles; c.halfLength c.halfDoubles; c.halfLength -c.halfDoubles];  % round the court
% the taps in order round their middle
m = mean(taps, 1);
[~, o] = sort(atan2(taps(:, 2) - m(2), taps(:, 1) - m(1)));
T = taps(o, :);
cam0 = struct('lens', lens, 'pos', [0 0 0], 'R', eye(3), 'width', lens.widthPx, 'height', lens.heightPx);
[dr, okr] = tv.camera.rays(cam0, T);                 % sight lines in the camera's own axes
if ~all(okr) || any(dr(:, 3) <= 0.05), error('tv:calib:corners', 'A tapped corner is outside what this lens can see.'); end
best = [];  bestErr = Inf;
for flip = 0:1
    for s = 0:3
        idx = circshift(1:4, s);
        if flip, idx = fliplr(idx); end
        Xa = X(idx, :);                              % court corner for each tap
        c1 = startPose(Xa, dr, cam0);
        if isempty(c1), continue; end
        [c1, e] = polish(c1, Xa, T);
        if c1.pos(3) < opts.minHeight || c1.pos(3) > opts.maxHeight || hypot(c1.pos(1), c1.pos(2)) > opts.maxRange, continue; end
        % the twins fit equally well: prefer the y <= 0 one, as tv.calib.searchPose
        if e < bestErr - 1e-6 || (abs(e - bestErr) <= 1e-6 && c1.pos(2) < best.pos(2))
            best = c1;  bestErr = e;
        end
    end
end
if isempty(best), error('tv:calib:corners', 'The four taps do not look like a court''s corners from any side.'); end
if best.pos(2) > 0, best = tv.calib.rotate180(best); end
cam = best;
report = struct('tapRmsPx', bestErr, 'rmsPx', NaN, 'inliers', 0, 'support', 0, 'refined', false, 'source', 'corners');
% refine on the lines, close to the tapped pose
[mask, ~] = tv.calib.linePixels(bg, opts.lineOpts);
sup0 = tv.calib.lineSupport(cam, mask);
report.support = sup0;
try
    tapped = cam;
    [cR, rep] = tv.calib.courtPose(bg, tapped, struct('searchDeg', opts.searchDeg, 'maxMove', opts.maxMove, 'lineOpts', opts.lineOpts));
    supR = tv.calib.lineSupport(cR, mask);
    % "at least as well", with a little slack: the share is counted within a few pixels, so a good
    % tapped pose can already score 1.00 and a sharper pose 0.99 (19 Nov: that turned a 1 cm fit away)
    if supR >= sup0 - opts.supportSlack && rep.inliers > 0 && isfinite(rep.rmsPx)
        cam = cR;  report.refined = true;  report.support = supR;  report.rmsPx = rep.rmsPx;  report.inliers = rep.inliers;
        % once more from there: the first round chose its line points from the tapped pose's view.
        % Still within opts.maxMove of the tapped pose in all; kept when it matches more line points.
        left = max(0.05, opts.maxMove - norm(cR.pos - tapped.pos));
        [c2, rep2] = tv.calib.courtPose(bg, cR, struct('searchDeg', 1, 'maxMove', left, 'lineOpts', opts.lineOpts));
        sup2 = tv.calib.lineSupport(c2, mask);
        if rep2.inliers >= rep.inliers && sup2 >= supR - opts.supportSlack && isfinite(rep2.rmsPx)
            cam = c2;  report.support = sup2;  report.rmsPx = rep2.rmsPx;  report.inliers = rep2.inliers;
        end
    end
catch err
    report.refineError = err.message;                % the tapped pose stands
end
Xw = [X, zeros(4, 1)];
[px, ok] = seen(cam, Xw);
% the final pose against the taps, whichever twin: each tap to its nearest corner
dd = zeros(4, 1);
for i = 1:4, dd(i) = min(hypot(px(ok, 1) - taps(i, 1), px(ok, 2) - taps(i, 2))); end
report.tapRmsPx = sqrt(mean(dd .^ 2));
end

function cam = startPose(Xa, dr, cam0)
% plane-to-picture fit: [x y 1]' on the ground maps to the sight line's (x/z, y/z)
n = dr(:, 1:2) ./ dr(:, 3);
A = zeros(8, 9);
for i = 1:4
    x = Xa(i, 1);  y = Xa(i, 2);  u = n(i, 1);  v = n(i, 2);
    A(2*i-1, :) = [x y 1 0 0 0 -u*x -u*y -u];
    A(2*i, :)   = [0 0 0 x y 1 -v*x -v*y -v];
end
[~, ~, V] = svd(A);
H = reshape(V(:, end), 3, 3)';
s = 2 / (norm(H(:, 1)) + norm(H(:, 2)));
H = H * s;
if H(3, 3) < 0, H = -H; end                          % the court is in front of the camera
r1 = H(:, 1);  r2 = H(:, 2);  t = H(:, 3);
[U, ~, W] = svd([r1, r2, cross(r1, r2)]);
R = U * diag([1 1 det(U * W')]) * W';                 % the nearest rotation
cam = cam0;
cam.R = R;                                            % rows: the camera's axes in court axes
cam.pos = (-R' * t)';
if any(~isfinite(cam.pos)), cam = []; end
end

function [cam, e] = polish(cam0, Xa, T)
% least squares on the pixel error of the four corners: position and a small turn
Xw = [Xa, zeros(4, 1)];
o = optimset('Display', 'off', 'TolFun', 1e-12, 'TolX', 1e-10, 'MaxIter', 200);
p = lsqnonlin(@res, zeros(1, 6), [], [], o);
cam = apply(p);
e = sqrt(mean(res(p) .^ 2) * 2);                     % rms distance in px (two residuals per corner)

    function c = apply(p)
        p = p(:)';                                   % the solver may hand back a column
        c = cam0;  c.pos = cam0.pos + p(1:3);
        a = p(4:6) * pi / 180;
        Rx = [1 0 0; 0 cos(a(1)) -sin(a(1)); 0 sin(a(1)) cos(a(1))];
        Ry = [cos(a(2)) 0 sin(a(2)); 0 1 0; -sin(a(2)) 0 cos(a(2))];
        Rz = [cos(a(3)) -sin(a(3)) 0; sin(a(3)) cos(a(3)) 0; 0 0 1];
        c.R = Rx * Ry * Rz * cam0.R;
    end
    function r = res(p)
        [px, ok] = seen(apply(p), Xw);
        r = reshape(px - T, [], 1);
        r(repmat(~ok, 2, 1)) = 1e3;                  % a corner behind the camera: far off
    end
end

function [px, ok] = seen(cam, P)
% pixels of court points, whether or not they fall inside the frame (a tapped corner can sit at
% its very edge, and tv.camera.project calls anything outside the frame unseen)
[u, v, ok] = tv.lens.project(cam.lens, cam, P);
px = [u + (cam.width + 1) / 2, v + (cam.height + 1) / 2];
end
