% GoPro Hero 7 (2.7K 4:3 Wide): the two-camera pipeline's own calibration, tv.calib.searchPose (no layout assumed)
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image; pkg load optim; pkg load statistics
out = '/home/user/private-footage/run5';
S = load([out '/stages/probe.mat']);  rec = S.rec;
bg = double(imread([out '/bg.png']));
cfg = tv.readJson('/home/user/tennis/vision/config/placement.json');
lens = tv.lens.atResolution(tv.lens.build(cfg.lenses, 'Wide', '4:3'), rec.width, rec.height);
lo = struct('minContrast', 20, 'minLength', 40, 'reach', [3 7]);
[mask, ~] = tv.calib.linePixels(bg, lo);
printf('line pixels: %d\n', nnz(mask));
imwrite(imresize(uint8(255 * imdilate(mask, ones(3))), 0.5), [out '/lines.png']);
tic; [cam, report] = tv.calib.searchPose(bg, lens, struct('lineOpts', lo, 'heights', [2.5 3.5 5]));
printf('search %.0f s\n', toc);  disp(report);
printf('camera at (%.2f %.2f %.2f)\n', cam.pos);
K = struct('cam', cam, 'bg', bg, 'report', report);
save('-binary', [out '/stages/calib.mat'], 'K');
img = uint8(bg);
[px, ok] = tv.camera.project(cam, tv.calib.modelPoints());
px = round(px(ok, :));  in = px(:, 1) > 2 & px(:, 1) < rec.width - 1 & px(:, 2) > 2 & px(:, 2) < rec.height - 1;  px = px(in, :);
r = img(:, :, 1); g = img(:, :, 2); b = img(:, :, 3);
for d = -1:1, for e = -1:1
  idx = sub2ind([rec.height rec.width], px(:, 2) + d, px(:, 1) + e);  r(idx) = 255; g(idx) = 0; b(idx) = 255;
end, end
imwrite(imresize(cat(3, r, g, b), 0.5), [out '/calib_check.jpg']);
