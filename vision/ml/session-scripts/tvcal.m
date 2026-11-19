% a phone video's camera from its court lines (env VID, FILE; OVL=1 when SwingVision's overlay boxes are in the picture)
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image; pkg load optim; pkg load statistics
v = getenv('VID');  out = ['/home/user/private-footage/run' v];
rec = tv.media.probe(getenv('FILE'));  printf('%d x %d, %.3f fps, %d frames\n', rec.width, rec.height, rec.fps, rec.nFrames);
save('-binary', [out '/stages/probe.mat'], 'rec');
tic; bg = tv.calib.background(rec, 61, [], 40);  printf('background %.0f s\n', toc);
if strcmp(getenv('OVL'), '1')        % the overlay boxes carry lines of their own: paint them out with the picture's middle colour
  B = [1630 10 1915 470; 1430 925 1915 1070];
  for k = 1:2, for c = 1:3, ch = bg(:, :, c); ch(B(k, 2):B(k, 4), B(k, 1):B(k, 3)) = median(ch(:)); bg(:, :, c) = ch; end, end
end
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
% for the review document: the line pixels found, and the court's lines through the fitted camera
[mask, ~] = tv.calib.linePixels(bg, struct('minContrast', 20, 'minLength', 40, 'reach', [3 7]));
imwrite(uint8(255 * imdilate(mask, ones(3))), [out '/lines.png']);
[px, ok] = tv.camera.project(cam, tv.calib.modelPoints());
px = round(px(ok, :));  in = px(:, 1) > 2 & px(:, 1) < rec.width - 1 & px(:, 2) > 2 & px(:, 2) < rec.height - 1;
dlmwrite([out '/model_px.csv'], px(in, :));
