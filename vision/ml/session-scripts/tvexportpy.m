% what the Python twin needs for one video (env VID): ball size map, camera, frame times, empty court
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
v = str2double(getenv('VID'));
S = load(sprintf('/home/user/private-footage/run%d/stages/calib.mat', v));  K = S.K;  cam = K.cam;
R = load(sprintf('/home/user/private-footage/run%d/stages/probe.mat', v));  rec = R.rec;
cfg = tv.pipeline.defaults(); box = tv.court.interest(cfg.court); c = tv.court.constants();
lo = [box.x(1), box.y(1), 0]; hi = [box.x(2), box.y(2), box.z(2)]; o = cam.pos(:)';
W = cam.width; H = cam.height; [uu, vv] = meshgrid(1:2:W, 1:2:H);
[D, ok] = tv.camera.rays(cam, [uu(:), vv(:)]);
t1 = (lo - o) ./ D; t2 = (hi - o) ./ D; t1(isnan(t1)) = -Inf; t2(isnan(t2)) = Inf;
tin = max(max(min(t1, t2), [], 2), 4);  tout = min(max(t1, t2), [], 2);
in = ok(:) & tout >= tin;
% pixels per radian at each pixel's own angle off the axis (a wide lens is not uniform)
th = tv.lens.angleAt(cam.lens, hypot(uu(:) - (W + 1) / 2, vv(:) - (H + 1) / 2) / (W / 2));
f = (tv.lens.radius(cam.lens, th + 1e-4) - tv.lens.radius(cam.lens, th)) / 1e-4 * W / 2;
dmax = 2 * c.ballRadius * f ./ tin;  dmin = 2 * c.ballRadius * f ./ tout;
dmax(~in) = 0; dmin(~in) = 0;
if strcmp(getenv('OVL'), '1'), ov = false(H, W); ov(10:470, 1630:1915) = true; ov(925:1070, 1430:1915) = true; ov = ov(1:2:end, 1:2:end); dmax(ov(:)) = 0; dmin(ov(:)) = 0; end   % SwingVision's boxes
fid = fopen(sprintf('/home/user/private-footage/ml/geom_v%d.f32', v), 'w');
fwrite(fid, [size(uu,1) size(uu,2)], 'float32'); fwrite(fid, reshape(dmin, size(uu))', 'float32'); fwrite(fid, reshape(dmax, size(uu))', 'float32'); fclose(fid);
printf('v%d: %.0f%% of the frame; ball diameter %.1f-%.1f px\n', v, 100*mean(in), min(dmin(in & dmin > 0)), max(dmax(in)));
lens = cam.lens;
th = linspace(0, deg2rad(lens.thetaMax) * 0.999, 2000)';
rho = tv.lens.radius(lens, th) * lens.widthPx / 2;
fid = fopen(sprintf('/home/user/private-footage/ml/cam_v%d.f64', v), 'w');
fwrite(fid, [cam.R(:); cam.pos(:); cam.width; cam.height; numel(th); th; rho], 'float64'); fclose(fid);
fid = fopen(sprintf('/home/user/private-footage/ml/pts_v%d.f64', v), 'w'); fwrite(fid, rec.pts, 'float64'); fclose(fid);
imwrite(uint8(K.bg), sprintf('/home/user/private-footage/ml/bg_v%d.png', v));
[px, ok] = tv.camera.project(cam, [3 1 1]); printf('v%d check %.3f %.3f; %d frames\n', v, px(1), px(2), rec.nFrames);
