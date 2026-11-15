function previewFrames(dataDir, outDir)
%PREVIEWFRAMES  Tracer stills and player pictures for the design preview (SYNTHETIC).
%   Renders camera 1's view of the synthetic court (tv.synth renderer, at
%   1280x720), the two players where each rally's last shot was hit, and the
%   rally's ball paths with tv.out.tracer. Also crops one picture per
%   player for "which one is you?".
if ~exist(fullfile(outDir, 'frames'), 'dir'), mkdir(fullfile(outDir, 'frames')); end
if ~exist(fullfile(outDir, 'players'), 'dir'), mkdir(fullfile(outDir, 'players')); end
sc = tv.synth.defaultScenario();  sc.frameSize = [1280 720];  sc.noiseSigma = 1.5;
cams = tv.synth.cameras(sc);
cam = cams(1);
bg = tv.synth.renderBackground(cam, sc);
shots = jsondecode(fileread(fullfile(dataDir, 'shots.json')));
traj = jsondecode(fileread(fullfile(dataDir, 'trajectories.json')));
players = sc.players;  players(1).capUntil = Inf;
for r = 1:8
    tr = traj([traj.rally] == r);
    sh = shots([shots.rally] == r);
    if isempty(tr), continue; end
    img = bg;
    % players at the last two contacts
    last = sh(end);  prev = sh(max(1, end - 1));
    both = [prev; last];
    for q = 1:2
        s = both(q);
        p = 1 + strcmp(s.hitter, 'Player B');
        foot = [s.contact(1) + sign(s.contact(1)) * 0.35, s.contact(2) - 0.7, 0];
        img = drawPerson(img, cam, foot, players(p));
    end
    for k = 1:numel(tr)
        img = tv.out.tracer(img, cam, tr(k).xyz);
    end
    imwrite(uint8(img), fullfile(outDir, 'frames', sprintf('rally_%02d.jpg', r)), 'Quality', 88);
end
% one picture per player, cropped and enlarged
for p = 1:2
    img = bg;
    foot = [-6 + 12 * (p - 1), -2, 0];
    img = drawPerson(img, cam, foot, players(p));
    [px, ok] = tv.camera.project(cam, [foot; foot + [0 0 2.0]]);
    cx = round(mean(px(:, 1)));  top = round(min(px(:, 2))) - 10;  bot = round(max(px(:, 2))) + 6;
    h = bot - top;  w = round(h * 0.75);
    crop = img(max(1, top):min(end, bot), max(1, cx - round(w / 2)):min(end, cx + round(w / 2)), :);
    crop = imresize(uint8(crop), [360 270], 'bicubic');
    label = {'player_a', 'player_b'};
    imwrite(crop, fullfile(outDir, 'players', [label{p} '.jpg']), 'Quality', 90);
end
end

function img = drawPerson(img, cam, foot, pl)
% the synthetic renderer's figure, drawn into a still
truth.players = {[0 foot(1) foot(2); 10 foot(1) foot(2)], [0 -12 -40; 10 -12 -40]};
sc.players = [pl, pl];  sc.staticBall = [99 99 0];  sc.noiseSigma = 0;  sc.flicker = 0;  sc.flickerHz = 0;
sc.ballRGB = [0 0 0];  sc.ballDrawScale = 1;
truth.T = (0:0.001:0.002)';  truth.ballP = nan(3, 3);
c = cam;  c.recordStart = 0;  c.clockOffset = 0;  c.clockDrift = 0;
img = double(tv.synth.renderFrame(c, img, sc, truth, 0, 1));
end
