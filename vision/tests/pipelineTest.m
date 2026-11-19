% The whole pipeline on synthetic footage with known answers (TV-TST-01).
% Generates the default synthetic session once (cached in the temp folder),
% runs tv.pipeline.run on it, and checks the spec's acceptance targets that
% synthetic footage can test. Slow: several minutes.
root = fullfile(tempdir, 'tv_pipeline_test');
gen = fullfile(root, 'synth');
if ~exist(fullfile(gen, 'truth.mat'), 'file')
    tv.synth.generate(gen);
end
T = load(fullfile(gen, 'truth.mat'));
files = {fullfile(gen, 'card1', 'DCIM', '100GOPRO', 'GX010011.MP4'), ...
         fullfile(gen, 'card2', 'DCIM', '100GOPRO', 'GX010012.MP4')};
cfg = tv.pipeline.defaults();
cfg.lineOpts = tv.calib.lineOptsFor('synthetic');     % the generator's clean lines; real footage uses lineOptsFor(width)
cfg.ballApparentScale = T.sc.ballDrawScale;
cfg.weather = struct('tempC', T.sc.weather.tempC, 'relHumidity', T.sc.weather.relHumidity, ...
    'pressurePa', T.sc.weather.pressurePa, 'wind10', 2 * T.sc.wind(1:2) + [0.8 -0.5]);  % a forecast, not the truth
cfg.notify = @(title, text) fprintf('[alert] %s: %s\n', title, text);
% the readout time is measured once per camera mode (spec, end of TV-PH-2); here: what it would measure
cfg.readoutPrior = mean(T.sc.readout);
resultFile = fullfile(root, 'result.mat');
if ~exist(resultFile, 'file')
    result = tv.pipeline.run(files, fullfile(root, 'out'), cfg);
    save(resultFile, 'result');
end
R = load(resultFile);
rep = tv.synth.compare(R.result, T.truth, T.cams, T.sc);
disp(rep); disp(rep.calls'); disp(rep.missing)
for k = 1:2
    fprintf('calib cam %d: rms %.2f px, %d of %d line points; true camera at %s\n', k, R.result.calib(k).rmsPx, ...
        R.result.calib(k).inliers, R.result.calib(k).points, mat2str(T.cams(k).pos, 3));
    disp(R.result.calib(k).candidates)
end
for r = 1:numel(R.result.segs)                 % what the pipeline saw, for diagnosis
    for g = R.result.segs{r}'
        fprintf('rally %d segment %.3f-%.3f rms %.2f n %d/%d\n', r, g.t0, max(g.t), g.rmsPx, g.n);
    end
    for e = R.result.events{r}
        fprintf('rally %d %s at %.3f (%.2f %.2f %.2f)\n', r, e.type, e.t, e.p);
    end
end
% On CI, keep the outputs where the workflow prints them (they become the app's sample session)
if ~isempty(getenv('CI'))
    keep = fullfile(pwd, 'out', 'pipeline');
    if ~exist(keep, 'dir'), mkdir(keep); end
    for f = {'session.json', 'shots.json', 'rallies.json', 'trajectories.json.gz'}
        if exist(fullfile(root, 'out', f{1}), 'file'), copyfile(fullfile(root, 'out', f{1}), keep); end
    end
    tv.util.writeJson(fullfile(keep, 'compare.json'), rep);
end
% A doubtful court-line fit (TV-CAL-21, 22): the session is held before detection and the question
% for the app is written; then the app's answer comes back. Run in a folder of its own, starting
% from the main run's saved probe and calibration stages (the same files and settings, so they
% are reused), with the alert level set above any fit so that both cameras are doubted.
hold0 = fullfile(root, 'out_hold');
if ~exist(fullfile(hold0, 'done.mat'), 'file')
    if exist(hold0, 'dir'), rmdir(hold0, 's'); end
    mkdir(fullfile(hold0, 'stages'));
    for nm = {'probe', 'calib'}
        for f = dir(fullfile(root, 'out', 'stages', [nm{1} '.*']))'
            copyfile(fullfile(root, 'out', 'stages', f.name), fullfile(hold0, 'stages'));
        end
    end
    H = struct();
    cfgH = cfg;  cfgH.minLineSupport = 1.01;
    H.id1 = '';
    try, tv.pipeline.run(files, hold0, cfgH); catch err, H.id1 = err.identifier; end
    H.check1 = tv.readJson(fullfile(hold0, 'calibration', 'calibration.json'));
    H.pics1 = [exist(fullfile(hold0, 'calibration', 'cam1.jpg'), 'file'), exist(fullfile(hold0, 'calibration', 'cam2.jpg'), 'file')] == 2;
    H.stages1 = arrayfun(@(d) d.name, dir(fullfile(hold0, 'stages', '*.manifest.json')), 'UniformOutput', false);
    % the answer: camera 1's four corners tapped a few pixels off; camera 2's taps nowhere near a court
    cc = tv.court.constants();
    X4 = [-cc.halfLength -cc.halfDoubles 0; -cc.halfLength cc.halfDoubles 0; cc.halfLength cc.halfDoubles 0; cc.halfLength -cc.halfDoubles 0];
    tv.util.seed(11);
    px4 = tv.camera.project(T.cams(1), X4);
    cfgC = cfgH;  cfgC.corners = {px4(randperm(4), :) + 4 * (2 * rand(4, 2) - 1), [100 40; 300 45; 310 120; 90 130]};
    H.id2 = '';
    try, tv.pipeline.run(files, hold0, cfgC); catch err, H.id2 = err.identifier; end
    S = load(fullfile(hold0, 'stages', 'calib.mat'));
    H.cams = S.out.cams;  H.report = rmfield(S.out.report, 'detail');
    H.check2 = tv.readJson(fullfile(hold0, 'calibration', 'calibration.json'));
    H.stages2 = arrayfun(@(d) d.name, dir(fullfile(hold0, 'stages', '*.manifest.json')), 'UniformOutput', false);
    save(fullfile(hold0, 'done.mat'), 'H');
end
H = load(fullfile(hold0, 'done.mat'));  H = H.H;

%% A doubtful court-line fit holds the session before detection and writes the question for the app (TV-CAL-21)
assert(strcmp(H.id1, 'tv:calib:doubtful'))
k1 = H.check1.checks;  if ~iscell(k1), k1 = num2cell(k1(:)'); end
assert(numel(k1) == 2 && all(H.pics1))                             % both cameras asked about, each with its picture
assert(strcmp(k1{1}.reason, 'lines') && k1{1}.width == T.cams(1).width && k1{1}.scale == 1)
assert(~any(ismember({'rallies.manifest.json', 'detect.manifest.json', 'recon.manifest.json'}, H.stages1)))   % nothing after calibration ran

%% Tapped corners place the camera within 0.1 m; taps that make no court are asked for again (TV-CAL-22)
assert(strcmp(H.id2, 'tv:calib:doubtful'))                         % camera 2 is still open, so the session still waits
assert(strcmp(H.report(1).source, 'corners') && isempty(H.report(1).tapError))
tw1 = tv.calib.rotate180(H.cams(1));
off1 = min(norm(H.cams(1).pos - T.cams(1).pos), norm(tw1.pos - T.cams(1).pos));
fprintf('camera 1 from four tapped corners: %.3f m from the truth, corners %.1f px from the taps\n', off1, H.report(1).tapRmsPx);
assert(off1 < 0.1)
k2 = H.check2.checks;  if ~iscell(k2), k2 = num2cell(k2(:)'); end
assert(numel(k2) == 1 && k2{1}.cam == 2 && strcmp(k2{1}.reason, 'taps'))   % only camera 2 is asked again
assert(~any(ismember({'rallies.manifest.json', 'detect.manifest.json'}, H.stages2)))

%% Camera poses from the court lines: within 5 cm and 0.2 degrees
assert(all(rep.cameraPosM < 0.05) && all(rep.cameraRotDeg < 0.2))

%% Court-line reprojection error within 1 px (AC-04)
assert(all([R.result.calib.rmsPx] < 1.0))

%% Camera timing within 0.5 ms (AC-05)
assert(abs(rep.syncErrMs) < 0.5)

%% Every shot falls inside a found rally (AC-03)
assert(rep.rallyCapture == 1)

%% At least 95% of shots reconstructed (AC-06)
assert(rep.shotsFound >= 0.95 * rep.shotsTrue)

%% Speed within 2 mph (0.89 m/s) for 90% of shots (AC-07)
assert(mean(rep.speedErr < 0.89) >= 0.9)

%% Median bounce error within 5 cm (AC-08)
assert(median(rep.bounceErr) < 0.05)

%% Spin effect within 10 cm (AC-10): median, at a quarter of 4K resolution (see DECISIONS)
assert(median(rep.spinEffectErr) < 0.10 && max(rep.spinEffectErr) < 0.40)

%% Shots credited to the right player, through the changeover (AC-13)
assert(mean(rep.hitterOk) >= 0.99)

%% No phantom hits: every hit found is within 30 ms of a true one
tHit = [T.truth.shots.tHit];
for r = 1:numel(R.result.events)
    ev = R.result.events{r};
    for e = ev(strcmp({ev.type}, 'hit'))
        assert(min(abs(tHit - e.t)) < 0.03, sprintf('phantom hit at %.3f s', e.t))
    end
end

%% Calls (in / out / net) match
assert(all(rep.callOk))

%% Output files are written
out = fullfile(root, 'out');
for f = {'session.json', 'shots.json', 'shots.csv', 'rallies.json', 'trajectories.json.gz', 'reel_1080p.mp4'}
    assert(exist(fullfile(out, f{1}), 'file') == 2, f{1})
end
