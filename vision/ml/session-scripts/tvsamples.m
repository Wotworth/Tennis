% per video: 200k random ball positions in the court's air space (over the court and its run-off,
% 0.1-4 m up), projected through the fitted camera: pixel and apparent diameter
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
rand('seed', 7);
for v = 1:3
  K = load(sprintf('/home/user/private-footage/run%d/stages/calib.mat', v)).out; cam = K.cam; c = tv.court.constants();
  n = 200000;
  P = [(rand(n,1)*2-1) * (c.halfLength + 4), (rand(n,1)*2-1) * (c.halfDoubles + 1.5), 0.1 + 3.9 * rand(n,1).^1.5];
  [px, ok] = tv.camera.project(cam, P);
  d = sqrt(sum((P - cam.pos(:)').^2, 2)); D = 2 * c.ballRadius * tv.lens.pxPerRad(cam.lens) ./ d;
  ok = ok & px(:,1) >= 25 & px(:,1) <= 1895 & px(:,2) >= 25 & px(:,2) <= 1055 & d > 4;
  if v < 3
    o = (px(:,1) >= 1630 & px(:,2) <= 470) | (px(:,1) >= 1430 & px(:,2) >= 925); ok = ok & ~o;
  end
  out = single([px(ok,:) D(ok)]);
  fid = fopen(sprintf('/home/user/private-footage/ml/samples_v%d.f32', v), 'w'); fwrite(fid, out', 'float32'); fclose(fid);
  printf('v%d: %d samples, diameter median %.1f px (10%%-90%%: %.1f-%.1f)\n', v, size(out,1), median(out(:,3)), prctile(out(:,3),10), prctile(out(:,3),90));
end
