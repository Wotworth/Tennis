addpath('/tmp/claude-0/scratchpad/vsnap');
for v = 1:3
  K = load(sprintf('/home/user/private-footage/run%d/stages/calib.mat', v)).out; cam = K.cam; lens = cam.lens;
  th = linspace(0, deg2rad(lens.thetaMax) * 0.999, 2000)';
  rho = tv.lens.radius(lens, th) * lens.widthPx / 2;
  fid = fopen(sprintf('/home/user/private-footage/ml/cam_v%d.f64', v), 'w');
  fwrite(fid, [cam.R(:); cam.pos(:); cam.width; cam.height; numel(th); th; rho], 'float64'); fclose(fid);
  % a check point for Python
  [px, ok] = tv.camera.project(cam, [3 1 1]); printf('v%d check %.3f %.3f\n', v, px(1), px(2));
end
