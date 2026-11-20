% calibCheckTest  A doubtful court-line fit: the question for the app and its answer (TV-CAL-21, 22).
% The hold itself (tv.pipeline.run stopping before detection) is in pipelineTest.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; pkg load optim; pkg load statistics; end

%% Which fits are doubtful: low line support, unless accepted; taps are taken unless they miss
cfg = tv.pipeline.defaults();
r = struct('source', 'lines', 'rmsPx', 1.2, 'support', cfg.minLineSupport - 0.05, 'tapRmsPx', NaN, 'tapError', '');
r(2) = r(1);  r(2).support = cfg.minLineSupport + 0.05;
D = tv.calib.doubt(r, [3840 3840], cfg);
assert(D(1).is && strcmp(D(1).reason, 'lines') && ~D(2).is)
assert(~isempty(strfind(D(1).text, '%')))                          % the alert says how much of the lines has paint
cfg.calibAccepted = [true false];                                  % "the lines are right"
D = tv.calib.doubt(r, [3840 3840], cfg);
assert(~D(1).is)
cfg.calibAccepted = [false false];
r(1).source = 'corners';  r(1).tapRmsPx = 0.5 * cfg.maxTapRms * 3840;   % tapped: the low line support no longer matters
D = tv.calib.doubt(r, [3840 3840], cfg);
assert(~D(1).is)
r(1).tapRmsPx = 2 * cfg.maxTapRms * 3840;                          % the taps do not make a court
D = tv.calib.doubt(r, [3840 3840], cfg);
assert(D(1).is && strcmp(D(1).reason, 'taps'))
r(1).source = 'lines';  r(1).support = 0.9;  r(1).tapError = 'A tapped corner is outside what this lens can see.';
D = tv.calib.doubt(r, [3840 3840], cfg);
assert(D(1).is && strcmp(D(1).reason, 'taps'))
fprintf('doubt: lines below %.2f, accepted, tapped, taps that miss\n', cfg.minLineSupport);

%% The check for the app: the picture, and the fitted lines lying on its paint; smaller when asked; removed when settled
cfg = tv.pipeline.defaults();
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
W = cams(1).width;  H = cams(1).height;
bg = tv.synth.renderBackground(cams(1), sc);
out = tempname();  mkdir(out);
C.cams = cams;  C.bg = {bg, bg};
C.report = struct('support', {0.2, 0.9}, 'rmsPx', {2, 1});
doubt = struct('is', {true, false}, 'reason', {'lines', ''}, 'text', {'Only 20% ...', ''});
cfg.checkPictureWidth = W;
J = tv.calib.writeCheck(out, C, doubt, cfg);
f = fullfile(out, 'calibration', 'calibration.json');
assert(exist(f, 'file') == 2 && exist(fullfile(out, 'calibration', 'cam1.jpg'), 'file') == 2)
assert(exist(fullfile(out, 'calibration', 'cam2.jpg'), 'file') == 0)       % only the doubtful camera is asked about
K = tv.readJson(f);
c = K.checks;  if iscell(c), c = c{1}; end
assert(c.cam == 1 && c.width == W && c.height == H && c.scale == 1 && strcmp(c.reason, 'lines'))
pic = double(imread(fullfile(out, 'calibration', 'cam1.jpg')));
assert(isequal(size(pic), [H W 3]))
% the lines sent are where the paint is in the sent picture: brighter under them than the picture at large
L = J.checks{1}.lines;
g = mean(pic, 3);  on = [];
for i = 1:numel(L)
    P = L{i};
    assert(size(P, 2) == 2 && all(P(:, 1) >= 0 & P(:, 1) <= c.width & P(:, 2) >= 0 & P(:, 2) <= c.height))
    u = min(max(round(P(:, 1) + 0.5), 1), c.width);  v = min(max(round(P(:, 2) + 0.5), 1), c.height);
    on = [on; g(sub2ind(size(g), v, u))]; %#ok<AGROW>
end
fprintf('check picture %d x %d: %d line runs, %d points; brightness under them %.0f against %.0f for the whole picture\n', ...
    W, H, numel(L), numel(on), median(on), median(g(:)));
assert(numel(L) >= 6 && median(on) > median(g(:)) + 30)
% a picture wider than the limit goes at a whole fraction of its size, and the lines with it
cfg.checkPictureWidth = W / 2;
J2 = tv.calib.writeCheck(out, C, doubt, cfg);
c2 = J2.checks{1};
assert(c2.width == W / 2 && c2.height == H / 2 && c2.scale == 0.5)
info = imfinfo(fullfile(out, 'calibration', 'cam1.jpg'));
assert(info.Width == W / 2 && info.Height == H / 2)
a = J.checks{1}.lines{1};  b = c2.lines{1};
assert(max(abs(a(:) / 2 - b(:))) < 0.11)                           % the same lines at half the scale
% with no doubt left the question is removed (the session is no longer held)
doubt(1).is = false;
tv.calib.writeCheck(out, C, doubt, cfg);
assert(exist(f, 'file') == 0)

%% The PC sends the picture and the check; taps come back as full-picture pixels; a bad answer asks again
cfg = tv.pipeline.defaults();
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
root = tempname();  out = fullfile(root, 's1');  mkdir(out);
C.cams = cams;  C.bg = {tv.synth.renderBackground(cams(1), sc), tv.synth.renderBackground(cams(2), sc)};
C.report = struct('support', {0.2, 0.1}, 'rmsPx', {2, 3});
doubt = struct('is', {true, true}, 'reason', {'lines', 'lines'}, 'text', {'a', 'b'});
cfg.checkPictureWidth = cams(1).width / 2;                          % so the answer has a scale to undo
tv.calib.writeCheck(out, C, doubt, cfg);
[c, log] = tv.testing.fakeClient();
n = tv.ops.calibrationCheck(out, 's1', c);
posts = log('post');
paths = cellfun(@(x) x{1}, posts, 'UniformOutput', false);
assert(n == 2 && nnz(strcmp(paths, '/sessions/s1/upload-url')) == 2 && numel(log('file')) == 2)
body = posts{find(strcmp(paths, '/calibration'), 1)}{2};
assert(numel(body.checks) == 2 && strcmp(body.checks{1}.sessionId, 's1') && body.checks{2}.cam == 2)
assert(strcmp(body.checks{1}.picturePath, 'calibration/cam1.jpg') && body.checks{1}.scale == 0.5)
assert(isempty(regexpi(jsonencode(body), 'court ?name|photo|heart|bpm', 'once')))   % no names or health data go up
L1 = body.checks{1}.lines;
assert(iscell(L1) && numel(L1) >= 6 && all(cellfun(@(q) size(q, 2) == 2 && size(q, 1) >= 2, L1)))   % a list of lines, each a run of [x y]
assert(strncmp(jsonencode(struct('lines', {L1(1)})), '{"lines":[[[', 12))                            % and written as one even when alone

wcfg.sessions = root;  wcfg.notify = @(t, m) [];
pc = rmfield(cfg, 'notify');
files = {'a.MP4', 'b.MP4'};  S0 = struct('cfg', pc);
save(fullfile(out, 'run.mat'), 'files');  save(fullfile(out, 'run.mat'), '-struct', 'S0', '-append');
taps = [10 20; 400 30; 420 250; 5 240];                             % in the sent (half-size) picture
pending = struct('conditions', [], 'identity', []);
pending.calibration = {struct('id', 4, 'sessionId', 's1', 'cam', 1, 'answer', 'corners', 'corners', taps, 'scale', 0.5), ...
                       struct('id', 5, 'sessionId', 's1', 'cam', 2, 'answer', 'accepted', 'corners', [], 'scale', 0.5)};
[c, log] = tv.testing.fakeClient(pending);
calls = containers.Map();  calls('cfgs') = {};  calls('up') = {};
res = struct('dataForUpload', struct('session', struct('headline', '7 rallies')));
runFn = @(f, o, p) tv.testing.recordCall(calls, 'cfgs', p, res);
up = @(o, id, r) tv.testing.recordCall(calls, 'up', id, []);
done = tv.ops.applyAnswers(wcfg, c, runFn, up);
cf = calls('cfgs');
assert(numel(done) == 1 && numel(cf) == 1 && numel(calls('up')) == 1)
assert(isequal(cf{1}.corners{1}, taps / 0.5 + 0.5) && isempty(cf{1}.corners{2}))
assert(isequal(cf{1}.calibAccepted, [false true]))
paths = cellfun(@(x) x{1}, log('post'), 'UniformOutput', false);
assert(any(strcmp(paths, '/calibration/4/applied')) && any(strcmp(paths, '/calibration/5/applied')))

% the taps did not make a court: the run stops again, nothing is uploaded, and the question goes up again
[c, log] = tv.testing.fakeClient(pending);
calls('up') = {};
bad = @tv.testing.doubtfulRun;
done = tv.ops.applyAnswers(wcfg, c, bad, up);
paths = cellfun(@(x) x{1}, log('post'), 'UniformOutput', false);
assert(numel(calls('up')) == 0 && any(strcmp(paths, '/calibration')) && any(strcmp(paths, '/calibration/4/applied')))
assert(~isempty(strfind(done{1}, 'asked again')))
fprintf('answers: corners at full size, "the lines are right", and a bad answer asked again\n');
