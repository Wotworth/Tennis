function S = ballSizeMap(cam, box, nearest)
%BALLSIZEMAP  Where the ball can be, and how big it can look there (TV-DET-04, 18 Nov).
%   For each pixel, its sight line is tested against the court of interest (box from
%   tv.court.interest); where it passes through, the ball can be anywhere from where the line
%   enters the box to where it leaves, so its diameter in pixels lies between dmin (leaving) and
%   dmax (entering, but never nearer than `nearest` m, default 4: a ball in play is not right at
%   the camera). S.mask, S.dmin, S.dmax: H-by-W. From the camera fit alone: nothing to tune.
if nargin < 3, nearest = 4; end
c = tv.court.constants();
lo = [box.x(1), box.y(1), max(0, box.z(1))];  hi = [box.x(2), box.y(2), box.z(2)];
o = cam.pos(:)';  f = tv.lens.pxPerRad(cam.lens);
H = cam.height;  W = cam.width;
S.dmin = zeros(H, W, 'single');  S.dmax = zeros(H, W, 'single');
for r0 = 1:100:H
    rows = r0:min(H, r0 + 99);
    [uu, vv] = meshgrid(1:W, rows);
    [D, ok] = tv.camera.rays(cam, [uu(:), vv(:)]);
    t1 = (lo - o) ./ D;  t2 = (hi - o) ./ D;
    t1(isnan(t1)) = -Inf;  t2(isnan(t2)) = Inf;
    tin = max(max(min(t1, t2), [], 2), nearest);  tout = min(max(t1, t2), [], 2);
    in = ok(:) & tout >= tin;
    dmax = 2 * c.ballRadius * f ./ tin;  dmin = 2 * c.ballRadius * f ./ tout;
    dmax(~in) = 0;  dmin(~in) = 0;
    S.dmax(rows, :) = reshape(dmax, numel(rows), W);
    S.dmin(rows, :) = reshape(dmin, numel(rows), W);
end
S.mask = S.dmax > 0;
end
