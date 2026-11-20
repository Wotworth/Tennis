function R = neighboursStudy(outDir, opts)
%NEIGHBOURSSTUDY  Chris's ball against courts in play next door, over many varied sessions (Chris, 22 Nov, item 5).
%   R = neighboursStudy('out/neighbours')
%   The ball-identity fixes of 21 Nov were tuned on one neighbours session (tests/adjacentTest.m).
%   This runs opts.n sessions (SYNTHETIC, default 6, each with Chris's two rallies), each built from
%   tv.synth.adjacentScenario with, drawn at random per session:
%     - the gap between the courts (3.0 to 4.5 m between the doubles sidelines)
%     - when each neighbouring rally starts, and where and how fast their shots go
%     - which of Chris's rallies the neighbour's ball crosses behind, and how high (0.8 to 2.0 m)
%     - when and where the stray rolls onto Chris's court
%     - how far outside Chris's court the sideline neighbour walks (1.5 to 4 m)
%     - Chris's own shots: targets moved up to 0.6 m and speeds up to 10% (the out and net shots
%       stay out and in the net)
%   Each session is rendered, run through the whole pipeline as on the PC, and scored as in
%   adjacentTest: Chris's shots found, his line calls right, his ball's detections rejected (AC-15),
%   the neighbours' accepted (AC-14), identity swaps (AC-16). Writes neighboursstudy.md and .csv.
%   Slow: about 15 minutes a session; the video of each session is deleted once scored.
if nargin < 1, outDir = fullfile(pwd, 'out', 'neighbours'); end
if nargin < 2, opts = struct(); end
d = struct('n', 6, 'seed', 1, 'keepVideo', false);
for f = fieldnames(d)', if ~isfield(opts, f{1}), opts.(f{1}) = d.(f{1}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
c = tv.court.constants();
rows = struct('session', {}, 'gapM', {}, 'crossRally', {}, 'crossH', {}, 'rollS', {}, 'sidelineM', {}, ...
    'shotsTrue', {}, 'shotsFound', {}, 'callsRight', {}, 'calls', {}, 'mineRejected', {}, 'othersAccepted', {}, 'swaps', {}, 'error', {});
for v = 1:opts.n
    tv.util.seed(1000 * opts.seed + v);
    sc = tv.synth.adjacentScenario();  sc.seed = 100 * opts.seed + v;
    gap = 3.0 + 1.5 * rand();  off = 2 * c.halfDoubles + gap;
    sc.neighbourCourts = [-off, off];
    sc.neighbourRallies(1).start = 0.5 + 7 * rand();
    sc.neighbourRallies(2).start = 12 + 8 * rand();
    for r = 1:numel(sc.neighbourRallies), sc.neighbourRallies(r).shots = jitter(sc.neighbourRallies(r).shots, 0.8, 0.15, false); end
    for r = 1:numel(sc.rallies), sc.rallies(r).shots = jitter(sc.rallies(r).shots, 0.6, 0.10, true); end
    sc.crossing = struct('rally', randi(numel(sc.rallies)), 'height', 0.8 + 1.2 * rand());
    sc.roll = struct('start', 5 + 17 * rand(), 'x', -8 + 16 * rand(), 'from', off - 4, 'to', 0.5 + 3 * rand(), 'speed', 3 + 2 * rand());
    side = 1.5 + 2.5 * rand();  sc.sidelineY = c.halfDoubles + side;
    row = struct('session', v, 'gapM', gap, 'crossRally', sc.crossing.rally, 'crossH', sc.crossing.height, 'rollS', sc.roll.start, ...
        'sidelineM', side, 'shotsTrue', NaN, 'shotsFound', NaN, 'callsRight', NaN, 'calls', NaN, 'mineRejected', NaN, ...
        'othersAccepted', NaN, 'swaps', NaN, 'error', '');
    root = fullfile(outDir, sprintf('s%02d', v));
    try
        gen = fullfile(root, 'synth');
        tv.synth.generate(gen, sc);
        T = load(fullfile(gen, 'truth.mat'));
        files = {fullfile(gen, 'card1', 'DCIM', '100GOPRO', 'GX010011.MP4'), fullfile(gen, 'card2', 'DCIM', '100GOPRO', 'GX010012.MP4')};
        cfg = tv.pipeline.defaults();
        cfg.lineOpts = tv.calib.lineOptsFor('synthetic');
        cfg.ballApparentScale = T.sc.ballDrawScale;
        cfg.weather = struct('tempC', T.sc.weather.tempC, 'relHumidity', T.sc.weather.relHumidity, ...
            'pressurePa', T.sc.weather.pressurePa, 'wind10', 2 * T.sc.wind(1:2) + [0.8 -0.5]);
        cfg.notify = @(title, text) fprintf('[alert] %s: %s\n', title, text);
        cfg.readoutPrior = mean(T.sc.readout);
        cfg.outputs.reel = false;
        result = tv.pipeline.run(files, fullfile(root, 'out'), cfg);
        M = tv.synth.adjacentMetrics(result, T.truth, T.cams, T.sc, cfg.adjacentTest);
        rep = tv.synth.compare(result, T.truth, T.cams, T.sc);
        row.shotsTrue = rep.shotsTrue;  row.shotsFound = rep.shotsFound;
        row.callsRight = nnz(rep.callOk);  row.calls = numel(rep.callOk);
        row.mineRejected = M.falseNeg;  row.othersAccepted = M.falsePos;  row.swaps = M.swaps;
        save(fullfile(root, 'scores.mat'), 'M', 'rep', 'sc');
    catch err
        row.error = err.message;
    end
    if ~opts.keepVideo && exist(fullfile(root, 'synth'), 'dir'), rmdir(fullfile(root, 'synth'), 's'); end
    rows(end+1) = row; %#ok<AGROW>
    fprintf('session %d: %d of %d shots, %d of %d calls right, mine rejected %.1f%%, others accepted %.2f%%, swaps %d %s\n', v, ...
        row.shotsFound, row.shotsTrue, row.callsRight, row.calls, 100 * row.mineRejected, 100 * row.othersAccepted, row.swaps, row.error);
end
R.rows = rows;  R.opts = opts;
writeOut(R, outDir);
end

function S = jitter(S, moveM, speedFrac, keepLast)
% shots {target, speed, CL, spin}: targets moved up to moveM, speeds by up to speedFrac; with
% keepLast the rally's last shot (Chris's deliberate out or net) is left as it is
c = tv.court.constants();
for i = 1:size(S, 1) - keepLast
    t = S{i, 1} + moveM * (2 * rand(1, 2) - 1);
    t(1) = sign(t(1)) * min(abs(t(1)), c.halfLength - 0.4);  t(2) = max(min(t(2), c.halfSingles - 0.3), -c.halfSingles + 0.3);
    S{i, 1} = t;  S{i, 2} = S{i, 2} * (1 + speedFrac * (2 * rand() - 1));
end
end

function writeOut(R, outDir)
r = R.rows;  ok = cellfun(@isempty, {r.error});
L = {'# Neighbours study: Chris''s ball with courts in play next door, varied sessions (SYNTHETIC)', ''};
L{end+1} = sprintf(['%d sessions (tools/neighboursStudy.m, seed %d), each with Chris''s two rallies and both neighbouring courts in play; ' ...
    'the courts'' gap, the neighbours'' timing and shots, the crossing ball, the stray and the sideline walker drawn at random per session.'], R.opts.n, R.opts.seed);
L{end+1} = '';
if any(ok)
    L{end+1} = sprintf('**All sessions:** shots found %d of %d; line calls right %d of %d; Chris''s ball rejected %.1f%% median (worst %.1f%%; limit 2%%, AC-15); neighbours'' detections accepted %.2f%% median (worst %.2f%%); identity swaps %d in all.', ...
        sum([r(ok).shotsFound]), sum([r(ok).shotsTrue]), sum([r(ok).callsRight]), sum([r(ok).calls]), 100 * median([r(ok).mineRejected]), 100 * max([r(ok).mineRejected]), ...
        100 * median([r(ok).othersAccepted]), 100 * max([r(ok).othersAccepted]), sum([r(ok).swaps]));
    L{end+1} = '';
end
L{end+1} = '| Session | Gap, m | Crossing: rally, height m | Stray at, s | Walker outside, m | Shots found | Calls right | Chris''s ball rejected | Others accepted | Swaps | Note |';
L{end+1} = '|---|---|---|---|---|---|---|---|---|---|---|';
for x = r(:)'
    L{end+1} = sprintf('| %d | %.2f | %d, %.2f | %.1f | %.1f | %d of %d | %d of %d | %.1f%% | %.2f%% | %d | %s |', x.session, x.gapM, x.crossRally, x.crossH, x.rollS, x.sidelineM, ...
        x.shotsFound, x.shotsTrue, x.callsRight, x.calls, 100 * x.mineRejected, 100 * x.othersAccepted, x.swaps, strrep(x.error, '|', '/')); %#ok<AGROW>
end
fid = fopen(fullfile(outDir, 'neighboursstudy.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
fid = fopen(fullfile(outDir, 'neighboursstudy.csv'), 'w');
fprintf(fid, 'session,gapM,crossRally,crossH,rollS,sidelineM,shotsTrue,shotsFound,callsRight,calls,mineRejected,othersAccepted,swaps\n');
for x = r(:)'
    fprintf(fid, '%d,%.3f,%d,%.3f,%.2f,%.2f,%d,%d,%d,%d,%.4f,%.4f,%d\n', x.session, x.gapM, x.crossRally, x.crossH, x.rollS, x.sidelineM, ...
        x.shotsTrue, x.shotsFound, x.callsRight, x.calls, x.mineRejected, x.othersAccepted, x.swaps);
end
fclose(fid);
end
