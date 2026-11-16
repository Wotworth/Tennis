function previewChecks(outDir, n)
%PREVIEWCHECKS  Sample "Ball check" crops for the app (SYNTHETIC): 256 x 256 around a ball.
%   Renders the synthetic court from camera 1 at 1280 x 720 with one ball
%   in flight, crops around the detector's guess (mostly on the ball, some
%   a little off, a few with no ball at all), and writes checks.json.
if nargin < 2, n = 20; end
d = fullfile(outDir, 'checks');  if ~exist(d, 'dir'), mkdir(d); end
sc = tv.synth.defaultScenario();  sc.frameSize = [1280 720];  sc.noiseSigma = 1.5;  sc.ballDrawScale = 1.6;
cams = tv.synth.cameras(sc);  cam = cams(1);
bg = tv.synth.renderBackground(cam, sc);
tv.util.seed(5);
items = struct('id', {}, 'file', {}, 'predX', {}, 'predY', {}, 'hasBall', {});
for k = 1:n
    P = [-10 + 20 * rand(), -4 + 8 * rand(), 0.3 + 2.2 * rand()];
    has = k > 3;
    truth.T = (0:0.001:0.01)';  truth.ballP = repmat(P, numel(truth.T), 1);
    if ~has, truth.ballP(:) = NaN; end
    truth.players = {[0 -12 -40; 10 -12 -40], [0 12 -40; 10 12 -40]};
    s = sc;  s.staticBall = [99 99 0];  s.flicker = 0;
    c = cam;  c.recordStart = 0;  c.clockOffset = 0;  c.clockDrift = 0;  c.readout = 0;
    img = tv.synth.renderFrame(c, bg, s, truth, 0, k);
    [px, ok] = tv.camera.project(cam, P);
    if ~ok, px = [640 360]; end
    pred = px;
    if has && mod(k, 4) == 0, pred = px + [14 -9]; end         % the detector a little off
    x0 = round(min(max(pred(1) - 128, 0), 1280 - 256));  y0 = round(min(max(pred(2) - 128, 0), 720 - 256));
    crop = img(y0 + 1:y0 + 256, x0 + 1:x0 + 256, :);
    f = sprintf('check_%02d.jpg', k);
    imwrite(crop, fullfile(d, f), 'Quality', 90);
    items(end+1) = struct('id', k, 'file', f, 'predX', pred(1) - x0, 'predY', pred(2) - y0, 'hasBall', has); %#ok<AGROW>
end
tv.util.writeJson(fullfile(outDir, 'checks.json'), struct('synthetic', true, 'checks', items));
end
