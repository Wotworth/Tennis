% Detector improvement loop (Chris, 15 Nov): test set and auto-labels, promotion, retraining, weekly.
root = tempname();  mkdir(root);
st = tv.learn.store(root);
% a fitted flight seen by both cameras (from the synthetic scenario's cameras)
sc = tv.synth.defaultScenario();  cams = tv.synth.cameras(sc);
air = tv.physics.defaultParams();
rec = struct('pts', {(0:3000)' / sc.fps, (0:3000)' / sc.fps}, 'height', {540, 540});
sync = struct('startOffset', [0 0], 'delta', 0, 'drift', 0, 'tref', 0, 'readout', [0 0], 'shutter', 0);
x = [-11.5 -1 1.0, 26 3 4, 0.1 0 0.507];
t0 = 100 / sc.fps;
frames = (100:150)';
obs = [];
for k = 1:2
    P = tv.recon.segmentModel(x, t0, frames / sc.fps, air);
    px = tv.camera.project(cams(k), P);
    obs = [obs; repmat(k, numel(frames), 1), frames, px]; %#ok<AGROW>
end
obs(obs(:, 2) == 120, :) = [];                  % a gap the physics fills
seg = struct('x', x, 't0', t0, 'rmsPx', 0.4, 'n', [50 50], 'obs', obs, 't', [], 'w', [], 'ok', true);
result = struct('segs', {{seg}}, 'cams', cams, 'rec', rec, 'sync', sync, 'air', air);

%% Auto-labels cover detected frames and short gaps of a flight both cameras agree on
L = tv.learn.harvest('s1', result);
assert(numel(L) >= 90 && any(strcmp({L.kind}, 'gap')))

%% A flight that does not fit well, or one camera only, gives no labels
bad = result;  bad.segs{1}.rmsPx = 3;
assert(isempty(tv.learn.harvest('s1', bad)))
one = result;  one.segs{1}.n = [50 0];
assert(isempty(tv.learn.harvest('s1', one)))

%% Frames where a player hides the ball are left out
L = tv.learn.harvest('s1', result);
f = L(1);
box = [f.cam, f.frame, f.xy(1) - 20, f.xy(2) - 40, 40, 80];
L2 = tv.learn.harvest('s1', result, struct('personBoxes', box));
assert(~any(strcmp({L2.key}, f.key)))

%% Test-set frames are never auto-labelled, and the store refuses them
A = struct('sessionId', 's1', 'frameRef', tv.learn.frameRef(1, 110), 'predX', 120, 'predY', 130, ...
    'answer', 'ok', 'ansX', NaN, 'ansY', NaN, 'answeredUtc', '2026-11-15T20:00:00Z', 'originX', 400, 'originY', 200, 'cam', 1, 'frame', 110);
tv.learn.testsetAdd(st, A);
keys = tv.learn.testsetKeys(st);
L = tv.learn.harvest('s1', result, struct('exclude', {keys}));
assert(~any(strcmp({L.key}, keys{1})))
Lall = tv.learn.harvest('s1', result);
threw = false;
try, tv.learn.saveAutolabels(st, 's1', Lall); catch, threw = true; end
assert(threw)
tv.learn.saveAutolabels(st, 's1', L);           % without the test frame: fine

%% A new model is promoted only if recall and precision are both no worse
T = struct('key', {'a', 'b', 'c', 'd'}, 'sessionId', 's', 'cam', 1, 'frame', 1, ...
    'xy', {[10 10], [20 20], [30 30], [NaN NaN]}, 'hasBall', {true, true, true, false}, 'answeredUtc', '');
truthXY = containers.Map({'a', 'b', 'c', 'd'}, {[10 10], [20 20], [30 30], [NaN NaN]});
img = @(key) truthXY(key);                                       % "frames": the true point
goodAll = @(F) [F 1] .* all(isfinite(F));                       % finds every ball
missOne = @(F) tv.testing.ternary(F(1) == 30, zeros(0, 3), [F 1]);         % misses one
falseAlarm = @(F) tv.testing.ternary(any(isnan(F)), [50 50 1], [F 1]);     % fires on the empty frame
old = struct('name', 'old', 'detect', @(F) tv.testing.gated(missOne, F));
new = struct('name', 'new', 'detect', @(F) tv.testing.gated(goodAll, F));
[p1, e1] = tv.learn.promote(st, old, new, T, img);
assert(p1 && e1.newRecall > e1.oldRecall)
worse = struct('name', 'worse', 'detect', falseAlarm);
[p2, e2] = tv.learn.promote(st, new, worse, T, img);
assert(~p2 && ~isempty(strfind(e2.why, 'precision')))
H = jsondecode(fileread(st.history));
assert(numel(H) == 2)

%% Retraining is due after 20,000 new auto-labelled frames
st2 = tv.learn.store(tempname());
n = 19999;  L = [];  save(fullfile(st2.autolabels, 'a.mat'), 'L', 'n');
assert(~tv.learn.retrainDue(st2, now))
n = 1;  save(fullfile(st2.autolabels, 'b.mat'), 'L', 'n');
assert(tv.learn.retrainDue(st2, now))

%% Ball checks favour unsure frames and skip frames already in the test set
c = struct('sessionId', 's1', 'cam', 1, 'frame', num2cell(1:30), 'xy', [5 5], 'day', 1, 'light', 0.5, 'unsure', num2cell(linspace(0, 1, 30)));
pick = tv.learn.selectChecks(c, 9, struct('exclude', {{'s1|cam1-f30'}}));
assert(numel(pick) == 9 && ~any([pick.frame] == 30) && pick(1).frame == 29)

%% The weekly message reports retraining and the open "looks wrong" flags
T = struct('key', {'a'}, 'sessionId', 's', 'cam', 1, 'frame', 1, 'xy', {[10 10]}, 'hasBall', true, 'answeredUtc', '');
tv.learn.promote(st, struct('name', 'old', 'detect', @(F) zeros(0, 3)), struct('name', 'new', 'detect', @(F) [F 1]), T, @(k) [10 10]);
cfg.notify = @(t, m) [];
pending = struct('conditions', [], 'identity', []);
[cl, log] = tv.testing.fakeClient(pending);
cl.getJson = @(path) struct('id', {1, 2, 3}, 'kind', {'looks wrong', 'missed shot', 'looks wrong'});
msg = tv.ops.weekly(cfg, cl, st, struct('sessionsThisWeek', 2, 'warnings', {{}}, 'diskFreeGB', 6000, 'diskTotalGB', 12000, 'gbPerWeek', 430));
assert(~isempty(strfind(msg, 'Retrained')) && ~isempty(strfind(msg, '2 open "looks wrong" flags')))

%% The learned detector trains and finds a ball (CPU here, GPU on the PC)
if exist('trainnet', 'file') && exist('minibatchpredict', 'file')
    tv.util.seed(3);
    S = struct('X', {}, 'xy', {});
    for k = 1:48
        X = 0.1 * rand(32, 48, 9, 'single');  p = [6 + 36 * rand(), 6 + 20 * rand()];
        [gx, gy] = meshgrid(1:48, 1:32);
        blob = single(exp(-((gx - p(1)).^2 + (gy - p(2)).^2) / 3));
        X(:, :, 4) = X(:, :, 4) + blob;  X(:, :, 5) = X(:, :, 5) + blob;     % yellow in the middle frame
        S(end+1) = struct('X', X, 'xy', p); %#ok<AGROW>
    end
    m = tv.learn.train(S(1:40), struct('width', 8, 'epochs', 30, 'batch', 8, 'learnRate', 3e-3));
    hits = 0;
    for k = 41:48
        C = tv.learn.detectNet(m, S(k).X, struct('minScore', 0.05));
        hits = hits + (~isempty(C) && hypot(C(1) - S(k).xy(1), C(2) - S(k).xy(2)) < 3);
    end
    assert(hits >= 6, 'found %d of 8', hits)
end
