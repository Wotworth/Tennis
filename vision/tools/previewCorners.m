function info = previewCorners(outDir)
%PREVIEWCORNERS  The sample "court corners" check for the app (SYNTHETIC; TV-CAL-21).
%   Renders the synthetic court from camera 1 at 1920 x 1080 and lays over it a fit that sits one
%   doubles alley to the side: the look-alike mistake seen on real footage (17 and 19 Nov), where
%   a sideline is laid on the neighbouring line. The check is written by the pipeline's own
%   tv.calib.doubt and tv.calib.writeCheck, then copied into the app's sample as corners.json and
%   corners/cam1.jpg. The spoof session shows no even numbers (docs/reports/SPOOF-SESSION.md), so
%   the shift is nudged until the share of lines with paint under them is an odd per cent.
%   info: the shift used (m), the share, and the true corners in the picture (for the app's test).
sc = tv.synth.defaultScenario();  sc.frameSize = [1920 1080];  sc.noiseSigma = 1.5;
cams = tv.synth.cameras(sc);  cam = cams(1);
bg = tv.synth.renderBackground(cam, sc);
c = tv.court.constants();
[mask, ~] = tv.calib.linePixels(bg, tv.calib.lineOptsFor('synthetic'));
cfg = tv.pipeline.defaults();
shift = c.halfDoubles - c.halfSingles;                 % one alley
for nudge = 0:0.01:0.3
    wrong = cam;  wrong.pos(2) = cam.pos(2) + shift + nudge;
    sup = tv.calib.lineSupport(wrong, mask);
    if mod(round(100 * sup), 2) == 1 && sup < cfg.minLineSupport, break; end
end
assert(mod(round(100 * sup), 2) == 1 && sup < cfg.minLineSupport, 'no odd share under the alert threshold was found');
tmp = tempname();  mkdir(tmp);
C.cams = [wrong, wrong];  C.bg = {bg, bg};
C.report = struct('source', {'lines', 'lines'}, 'rmsPx', {1.3, 1.3}, 'support', {sup, 1}, 'tapRmsPx', {NaN, NaN}, 'tapError', {'', ''});
D = tv.calib.doubt(C.report, [1920 1920], cfg);
J = tv.calib.writeCheck(tmp, C, D, cfg);
k = J.checks{1};
d = fullfile(outDir, 'corners');  if ~exist(d, 'dir'), mkdir(d); end
copyfile(fullfile(tmp, 'calibration', 'cam1.jpg'), fullfile(d, 'cam1.jpg'));
item = struct('id', 1, 'sessionId', 'sample', 'cam', k.cam, 'file', 'cam1.jpg', 'width', k.width, 'height', k.height, ...
    'support', round(100 * sup) / 100, 'reason', k.reason, 'lines', {k.lines});
tv.util.writeJson(fullfile(outDir, 'corners.json'), struct('synthetic', true, 'checks', {{item}}));
X = [-c.halfLength -c.halfDoubles 0; -c.halfLength c.halfDoubles 0; c.halfLength c.halfDoubles 0; c.halfLength -c.halfDoubles 0];
px = tv.camera.project(cam, X);
info = struct('shift', shift + nudge, 'support', sup, 'corners', px - 0.5);
fprintf('sample court corners: fit %.2f m to the side, paint under %.0f%% of its lines; true corners (picture px):\n', info.shift, 100 * sup);
disp(round(info.corners * 10) / 10)
end
