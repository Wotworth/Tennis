% tools/groundTruthReport.m (Chris, 20 Nov): Tuesday's accuracy report, on made-up inputs with known answers.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; pkg load statistics; end
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'tools'));

%% Drops: gravity and release height from the 3D points of each fall; cameras against the tape
tv.util.seed(1);
M = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'groundtruth', 'template.json'));
res.gatePoints = {};                                        % the gate's kept 3D points [t x y z] (22 Nov)
t0 = 2;
for d = 1:3
    t = (0:1 / 240:0.6)';                                   % 0.6 s of fall (2.03 m takes 0.64 s)
    z = 2.0335 - 0.5 * 9.81 * t .^ 2 + 0.004 * randn(size(t));
    res.gatePoints{end+1} = [t0 + t, zeros(numel(t), 2), z];
    t0 = t0 + 5;
end
res.events = {};  res.shots = [];
runs = struct('clip2', res);
sc = tv.synth.defaultScenario();  sc.lensName = 'Linear';  c = tv.court.constants();  sc.mountX = c.halfLength + 2.5;
cams = tv.synth.cameras(sc);
runs.cams = cams;
G = groundTruthReport(M, runs);
fprintf('%s\n', G.text);
assert(numel(G.drop.g) == 3 && all(abs(G.drop.g - 9.81) < 0.1) && all(abs(G.drop.top - 2.0335) < 0.01))
% the template's camera spots are the synthetic Linear set-up's, give or take its aim: within a few cm
assert(all([G.cameras.err] < 0.6))

%% Still balls: found in both pictures and placed by the two sight lines within a few cm
sc = tv.synth.defaultScenario();  sc.frameSize = [1920 1080];
cams = tv.synth.cameras(sc);
bg = cell(1, 2);  fr = cell(1, 2);
M = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'groundtruth', 'template.json'));
balls = M.stillBalls.balls;  if iscell(balls), balls = [balls{:}]; end
for k = 1:2
    bg{k} = tv.synth.renderBackground(cams(k), sc);
    img = bg{k};
    [X, Y] = meshgrid(1:size(img, 2), 1:size(img, 1));
    for b = balls(:)'
        [px, ok] = tv.camera.project(cams(k), [b.x b.y b.z]);
        if ~ok, continue; end
        rpx = max(1.5, 0.0335 / norm([b.x b.y b.z] - cams(k).pos) * tv.lens.pxPerRad(cams(k).lens));
        cover = min(max(rpx + 0.5 - hypot(X - px(1), Y - px(2)), 0), 1);
        img = img .* (1 - cover) + reshape([205 230 40], 1, 1, 3) .* cover;
    end
    fr{k} = uint8(img);
end
runs = struct('stillFrames', {fr}, 'bg', {bg}, 'cams', cams);
G = groundTruthReport(M, runs);
fprintf('%s\n', G.text);
found = [G.still.found];
assert(nnz(found) >= 5)
assert(all([G.still(found).err] < 0.05))

%% Targets: bounces matched to the taped crosses
M = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'groundtruth', 'template.json'));
ev = struct('type', {'bounce', 'bounce', 'hit', 'bounce'}, 't', {1, 2, 3, 4}, 'p', {[11.40 -4.97 0.03], [11.36 -5.01 0.03], [0 0 1], [11.37 4.99 0.03]}, ...
    'segBefore', {1, 1, 1, 1}, 'segAfter', {2, 2, 2, 2});
runs = struct('clip3', struct('events', {{ev}}));
G = groundTruthReport(M, runs);
assert(G.targets(1).n == 2 && G.targets(2).n == 1 && G.targets(1).worst < 0.04)

%% Spin: the striped balls against the system's rpm for the same feeds (22 Nov, item 6)
M = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'groundtruth', 'template.json'));
sh = struct('index', {1, 2, 1, 1}, 'rpm', {2000, 900, 2500, 3100}, 'rpmSd', {100, 100, 60, 60}, ...
    'speedContact', 20, 'spinEffect', 0.3, 'bounce', [8 0]);
st.balls = struct('rpm', {2050, 2480, 2700}, 'rpmSd', {20, 20, 20});
runs = struct('clip8', struct('shots', sh), 'stripe', st);
G = groundTruthReport(M, runs);
assert(numel(G.spin.rows) == 3 && G.spin.nFeeds == 3)
assert(isequal([G.spin.rows.inside], [true true false]))      % the third: 400 rpm off, band 2 x 63
assert(abs(G.spin.medianDiff - 50) < 1e-9)
assert(~isempty(strfind(G.text, 'Striped ball')))

%% The numbers for the app's accuracy page (22 Nov, item 14)
M = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'groundtruth', 'template.json'));
sh = struct('index', {1, 2, 1, 1}, 'rpm', {2000, 900, 2500, 3100}, 'rpmSd', {100, 100, 60, 60}, ...
    'speedContact', 20, 'spinEffect', 0.3, 'bounce', [8 0]);
st.balls = struct('rpm', {2050, 2480, 2700}, 'rpmSd', {20, 20, 20});
runs = struct('clip8', struct('shots', sh), 'stripe', st);
out = [tempname() '.md'];
G = groundTruthReport(M, runs, out);
[dd, bb] = fileparts(out);
A = jsondecode(fileread(fullfile(dd, [bb '.json'])));
assert(isfield(A, 'spin') && numel(A.spin.rows) == 3 && abs(A.spin.medianDiffRpm - 50) < 1e-9)
assert(isfield(A, 'machine') && ~isempty(A.machine))
