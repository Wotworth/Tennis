% Chris's court only, with a court on each side in play (TV-ADJ-07, TV-ADJ-08, AC-14 to AC-16).
% Generates the adjacent-courts synthetic session once (cached in the temp folder),
% runs the whole pipeline on it, and scores what was accepted and rejected against
% the truth. Thresholds: tv.pipeline.defaults' cfg.adjacentTest (the PC's config can
% change them). Slow: several minutes.
root = fullfile(tempdir, 'tv_adjacent_test');
gen = fullfile(root, 'synth');
if ~exist(fullfile(gen, 'truth.mat'), 'file')
    tv.synth.generate(gen, tv.synth.adjacentScenario());
end
T = load(fullfile(gen, 'truth.mat'));
files = {fullfile(gen, 'card1', 'DCIM', '100GOPRO', 'GX010011.MP4'), ...
         fullfile(gen, 'card2', 'DCIM', '100GOPRO', 'GX010012.MP4')};
cfg = tv.pipeline.defaults();
cfg.ballApparentScale = T.sc.ballDrawScale;
cfg.weather = struct('tempC', T.sc.weather.tempC, 'relHumidity', T.sc.weather.relHumidity, ...
    'pressurePa', T.sc.weather.pressurePa, 'wind10', 2 * T.sc.wind(1:2) + [0.8 -0.5]);
cfg.notify = @(title, text) fprintf('[alert] %s: %s\n', title, text);
cfg.readoutPrior = mean(T.sc.readout);
cfg.outputs.reel = false;
resultFile = fullfile(root, 'result.mat');
if ~exist(resultFile, 'file')
    result = tv.pipeline.run(files, fullfile(root, 'out'), cfg);
    save(resultFile, 'result');
end
R = load(resultFile);
M = tv.synth.adjacentMetrics(R.result, T.truth, T.cams, T.sc, cfg.adjacentTest);
rep = tv.synth.compare(R.result, T.truth, T.cams, T.sc);
fprintf('adjacent courts: accepted %d detections, %d of them not Chris''s ball: false positives %.2f%% (limit %.2f%%)\n', ...
    M.accepted, M.acceptedOther, 100 * M.falsePos, 100 * M.limits.maxFalsePos);
fprintf('Chris''s ball: %d detections in tracks, %d rejected: false negatives %.2f%% (limit %.2f%%); %d more truly outside the court of interest (rejected by design)\n', ...
    M.mineInTrack, M.mineRejected, 100 * M.falseNeg, 100 * M.limits.maxFalseNeg, M.mineOutsideBox);
fprintf('identity swaps %d (hits %d, track switches %d, neighbours kept %d; limit %d)\n', ...
    M.swaps, M.hitSwaps, M.trackSwaps, M.neighbourKept, M.limits.maxSwaps);
disp(M.byKind); disp(struct2table(M.mineRejectedWhy)); disp(rep.calls');
counts = jsondecode(fileread(fullfile(root, 'out', 'session.json'))).rejects.counts;
disp(struct2table(counts))
if ~isempty(getenv('CI'))
    keep = fullfile(pwd, 'out', 'adjacent');
    if ~exist(keep, 'dir'), mkdir(keep); end
    tv.util.writeJson(fullfile(keep, 'adjacent.json'), M);
    copyfile(fullfile(root, 'out', 'rejects', 'rejects.html'), keep);
    copyfile(fullfile(root, 'out', 'rejects', 'rejects.csv'), keep);
end

%% Neighbours' balls accepted: at most the limit (AC-14)
assert(M.falsePos <= M.limits.maxFalsePos)

%% Chris's ball rejected: at most the limit (AC-15)
assert(M.falseNeg <= M.limits.maxFalseNeg)

%% Identity swaps: at most the limit (AC-16)
assert(M.swaps <= M.limits.maxSwaps)

%% Chris's shots are all still found and called with the neighbours playing (AC-06)
assert(rep.shotsFound >= 0.95 * rep.shotsTrue)
assert(all(rep.callOk))

%% The neighbours' balls, the crossing ball and the rolling stray were all seen, and rejected
for f = setdiff(fieldnames(M.byKind), {'mine', 'none'})'
    k = M.byKind.(f{1});
    assert(k.detected > 0, '%s never detected: the test does not test it', f{1})
end

%% Every rejection has a reason in the session's reject log
assert(~isempty(counts) && all(arrayfun(@(c) ~isempty(c.reason), counts)))
