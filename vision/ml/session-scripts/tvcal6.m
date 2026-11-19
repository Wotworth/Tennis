% iPhone full-match recording (3 Oct 2025), a 5-minute window: camera from the court lines as for the other iPhone videos
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image; pkg load optim; pkg load statistics
out = '/home/user/private-footage/run6';
rec = tv.media.probe('/home/user/private-footage/s6/clip6.mp4');  printf('%d x %d, %.3f fps, %d frames\n', rec.width, rec.height, rec.fps, rec.nFrames);
save('-binary', [out '/stages/probe.mat'], 'rec');
tic; bg = tv.calib.background(rec, 61, [], 40);  printf('background %.0f s\n', toc);
imwrite(uint8(bg), [out '/bg.png']);
h = 65;
E = struct('name', 'single', 'aspect', 'any', 'hfov', h, 'vfov', 2 * atand(tand(h / 2) * rec.height / rec.width), ...
    'dfov', 2 * atand(tand(h / 2) * hypot(rec.width, rec.height) / rec.width), 'widthPx', rec.width, 'heightPx', rec.height, 'model', 'rectilinear');
lens = tv.lens.atResolution(tv.lens.build(E, 'single', 'any'), rec.width, rec.height);
tic; [cam, report] = tv.calib.courtFromLines(bg, lens, struct('lineOpts', struct('minContrast', 20, 'minLength', 40, 'reach', [3 7]), 'fitFocal', true));
printf('calibration %.0f s: rms %.2f px, inliers %d, support %.2f, hfov %.1f deg\n', toc, report.rmsPx, report.inliers, report.support, report.hfovDeg);
printf('camera at (%.2f %.2f %.2f)\n', cam.pos);
K = struct('cam', cam, 'bg', bg, 'report', rmfield(report, intersect(fieldnames(report), {'lines'})));
save('-binary', [out '/stages/calib.mat'], 'K');
img = uint8(bg);
[px, ok] = tv.camera.project(cam, tv.calib.modelPoints());
px = round(px(ok, :));  in = px(:, 1) > 2 & px(:, 1) < rec.width - 1 & px(:, 2) > 2 & px(:, 2) < rec.height - 1;  px = px(in, :);
r = img(:, :, 1); g = img(:, :, 2); b = img(:, :, 3);
for d = -1:1, idx = sub2ind([rec.height rec.width], px(:, 2) + d, px(:, 1));  r(idx) = 255; g(idx) = 0; b(idx) = 255; end
imwrite(cat(3, r, g, b), [out '/calib_check.jpg']);
