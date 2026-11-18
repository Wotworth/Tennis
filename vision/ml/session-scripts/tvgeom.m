% per video: where the ball can be (court of interest, overlays out) and the ball's diameter
% range in pixels at each pixel (sight line through the box: nearest and farthest), half resolution
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
for v = 1:3
  K = load(sprintf('/home/user/private-footage/run%d/stages/calib.mat', v)).out; cam = K.cam;
  cfg = tv.pipeline.defaults(); box = tv.court.interest(cfg.court); c = tv.court.constants();
  lo = [box.x(1), box.y(1), 0]; hi = [box.x(2), box.y(2), box.z(2)]; o = cam.pos(:)';
  W = cam.width; H = cam.height; [uu, vv] = meshgrid(1:2:W, 1:2:H);
  [D, ok] = tv.camera.rays(cam, [uu(:), vv(:)]);
  t1 = (lo - o) ./ D; t2 = (hi - o) ./ D; t1(isnan(t1)) = -Inf; t2(isnan(t2)) = Inf;
  tin = max(max(min(t1, t2), [], 2), 4);   % a ball in play is at least ~4 m from the camera
  tout = min(max(t1, t2), [], 2);
  in = ok(:) & tout >= tin;
  f = tv.lens.pxPerRad(cam.lens);
  dmax = 2 * c.ballRadius * f ./ tin;  dmin = 2 * c.ballRadius * f ./ tout;
  dmax(~in) = 0; dmin(~in) = 0;
  if v < 3, ov = false(H, W); ov(10:470, 1630:1915) = true; ov(925:1070, 1430:1915) = true; ov = ov(1:2:end, 1:2:end); dmax(ov(:)) = 0; dmin(ov(:)) = 0; end
  fid = fopen(sprintf('/home/user/private-footage/ml/geom_v%d.f32', v), 'w');
  fwrite(fid, [size(uu,1) size(uu,2)], 'float32'); fwrite(fid, reshape(dmin, size(uu))', 'float32'); fwrite(fid, reshape(dmax, size(uu))', 'float32'); fclose(fid);
  printf('v%d: %.0f%% of the frame; diameter %.1f-%.1f px\n', v, 100*mean(in), min(dmin(in & dmin > 0)), max(dmax(in)));
end
