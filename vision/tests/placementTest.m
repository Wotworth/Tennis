% Camera placement check (TV-CAL-03, TV-CAL-04).
cfg = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'config', 'placement.json'));
c = tv.court.constants();
W = tv.lens.build(cfg.lenses, 'Wide', '16:9');
pts = tv.court.playVolume(cfg.volume.behindBaseline, cfg.volume.maxHeight, cfg.volume.step);

%% Spec: from the service-line spots a camera needs about 132 degrees across
cam = [c.serviceLine, -(c.halfDoubles + 4)];
corners = [c.halfLength, -c.halfDoubles; -c.halfLength, -c.halfDoubles; -c.halfLength, c.halfDoubles];
az = atan2d(corners(:,2) - cam(2), corners(:,1) - cam(1));
assert(abs(max(az) - min(az) - 132) < 1)

%% Spec: near the baselines it needs 115-120 degrees, with 3 m behind each baseline
cam = [c.halfLength, -(c.halfDoubles + 4)];
xe = c.halfLength + 3;
edges = [xe, -c.halfDoubles; -xe, -c.halfDoubles; -xe, c.halfDoubles; xe, c.halfDoubles];
az = atan2d(edges(:,2) - cam(2), edges(:,1) - cam(1));
span = max(az) - min(az);
assert(span > 115 && span < 120)

%% Spec: from the baseline spots the sight lines cross at about 100 degrees at the net centre
a = [0 0] - [-c.halfLength, -(c.halfDoubles + 4)];
b = [0 0] - [ c.halfLength, -(c.halfDoubles + 4)];
ang = acosd(dot(a, b) / (norm(a) * norm(b)));
assert(abs(ang - 100) < 5)

%% Bounce error grows in proportion to the pixel error
cam1 = tv.placement.pose([-11.885 -9.485 3], 67, -8);
cam2 = tv.placement.pose([ 11.885 -9.485 3], 113, -8);
p = [-11.885 5.485 c.ballRadius];
e1 = tv.placement.stereoError(W, cam1, cam2, p, 1);
e2 = tv.placement.stereoError(W, cam1, cam2, p, 2);
assert(abs(e2 / e1 - 2) < 1e-6)

%% The baseline spots 4 m out see the whole play volume with the Wide lens in 16:9
r = tv.placement.evaluate(cfg, W, 4, c.halfLength, 3, pts);
assert(r.coverage == 1)
assert(abs(r.cam2.yaw - (180 - r.cam1.yaw)) < 1e-9)

%% A fence farther away makes the far-corner ball smaller
near = tv.placement.evaluate(cfg, W, 4, c.halfLength, 3, pts);
far  = tv.placement.evaluate(cfg, W, 9, c.halfLength, 3, pts);
assert(far.ballPx < near.ballPx)

%% Layout 2 (back-fence corners, same side): weakest crossing is at the net on the cameras' side
cfg2 = cfg;  cfg2.layout2.lenses = {'Wide'};  cfg2.aspects = {'16:9'};
cfg2.layout2.backDistances = 6.4;  cfg2.layout2.sideDistances = 3.66;
r2 = tv.placement.corners(cfg2);
assert(numel(r2) == 1 && r2.coverage == 1)
assert(abs(r2.worstX) < 1 && r2.worstY < -5)          % over the cameras' doubles sideline, at the net
assert(r2.courtCrossDeg > 20 && r2.courtCrossDeg < 35)
assert(r2.ballPx > 3 && r2.ballPx < 4)                % smaller than layout 1's ~4 px
assert(r2.farRangeM > 32 && r2.farRangeM < 35)

