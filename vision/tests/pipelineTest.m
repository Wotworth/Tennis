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

%% Calls (in / out / net) match
assert(all(rep.callOk))

%% Output files are written
out = fullfile(root, 'out');
for f = {'session.json', 'shots.json', 'shots.csv', 'rallies.json', 'trajectories.json.gz', 'reel_1080p.mp4'}
    assert(exist(fullfile(out, f{1}), 'file') == 2, f{1})
end
