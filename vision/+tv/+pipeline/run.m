function result = run(files, outDir, cfg)
%RUN  Process one session from its two recordings to shots, rallies and files.
%   result = tv.pipeline.run({cam1File, cam2File}, outDir, cfg)
%   Stages, each saved and skipped when unchanged (tv.pipeline.stage):
%     probe    frame times and start times of both files (TV-ING-10)
%     calib    the empty court and each camera's pose from its lines, searched
%              all round the court with no layout assumed (TV-CAL-10 to 13)
%     rallies  rally windows from the sound of the ball (TV-RAL-01, 02)
%     detect   ball candidates and 2D tracks in every rally (TV-DET, TV-TRK)
%     sync     which of each pose's half-turn twins is right (both cameras must
%              agree on the ball and the players), camera 2's clock against
%              camera 1's (TV-SYNC-01 to 03), and the crossing-angle report;
%              weak zones go into an alert
%     recon    flights, session timing, wind and drag, events (TV-REC, TV-PHY-03, TV-EVT)
%     players  people, tracks and which one is Chris (TV-PLY)
%     metrics  shots, rallies, session summary (section 5)
%     outputs  session.json, shots, trajectories, rallies, plots, reel (TV-OUT)
if nargin < 3 || isempty(cfg), cfg = tv.pipeline.defaults(); end
if ~exist(outDir, 'dir'), mkdir(outDir); end
key0 = [files{1} '|' files{2} '|' fileStamp(files{1}) '|' fileStamp(files{2})];
% what this session was run with, so an app answer can rerun it later (tv.ops.applyAnswers)
saved = rmfield(cfg, intersect(fieldnames(cfg), {'notify'}));
save(fullfile(outDir, 'run.mat'), 'files');  S0 = struct('cfg', saved);  save(fullfile(outDir, 'run.mat'), '-struct', 'S0', '-append');
k = @(varargin) [key0 '|' jsonencode(varargin)];

% --- probe ---------------------------------------------------------------------------
S = tv.pipeline.stage(outDir, 'probe', k(), @() probeBoth(files));
rec = S.rec;  sync = S.sync;  sync.readout = cfg.readoutPrior * [1 1];  sync.shutter = cfg.shutter;

% --- calibration ------------------------------------------------------------------------
C = tv.pipeline.stage(outDir, 'calib', k('search', cfg.lensName, cfg.aspect), @() calibrate(rec, cfg));

% --- rallies ------------------------------------------------------------------------------
R = tv.pipeline.stage(outDir, 'rallies', k(), @() findRallies(rec));

% --- detection and 2D tracks -----------------------------------------------------------------
D = tv.pipeline.stage(outDir, 'detect', k(R.windows, cfg.ballApparentScale), ...
    @() detectAll(rec, C, R.windows, sync, cfg));

% --- sync ---------------------------------------------------------------------------------------
Y = tv.pipeline.stage(outDir, 'sync', k(R.windows, cfg.minCrossDeg), @() syncAll(D, C, R, rec, sync, cfg));
sync = Y.sync;  cams = Y.cams;  C.cams = cams;
if ~isempty(Y.crossing.low), cfg.notify('Camera angle', Y.crossing.text); end

% --- reconstruction ---------------------------------------------------------------------------------
air0 = tv.physics.defaultParams();
air0.rho = tv.air.density(cfg.weather.tempC, cfg.weather.relHumidity, cfg.weather.pressurePa);
if cfg.indoor   % TV-IND-01: indoor temperature and humidity, pressure from the weather, no wind
    air0.rho = tv.air.density(cfg.indoorDefaults.tempC, cfg.indoorDefaults.relHumidity, cfg.weather.pressurePa);
end
air0.wind = [0.5 * cfg.weather.wind10, 0];            % TV-PHY-04: half the 10 m forecast
if cfg.indoor, air0.wind = [0 0 0]; end
X = tv.pipeline.stage(outDir, 'recon', k(sync, Y.symmetry.chosen, cfg.weather, cfg.indoor, cfg.CDprior, cfg.refineRounds), ...
    @() reconstruct(D, cams, rec, sync, air0, cfg));

% --- players ----------------------------------------------------------------------------------
P = tv.pipeline.stage(outDir, 'players', k(cfg.playerHz, Y.symmetry.chosen), @() trackPlayers(rec, C, X.sync, cfg));

% --- metrics ------------------------------------------------------------------------------------
if isfield(cfg, 'chrisLabel') && ~isempty(cfg.chrisLabel), P = relabel(P, cfg.chrisLabel); end
M = tv.pipeline.stage(outDir, 'metrics', k(cfg.lines, P.info.chris), @() measure(X, R, cams, P));

% --- outputs ----------------------------------------------------------------------------------------
[up.summary, up.data] = tv.upload.payload(struct('rec', rec, 'shots', M.shots, 'rallies', M.rallies, ...
    'summary', M.summary, 'air', X.air, 'players', P));
result = struct('summaryForUpload', up.summary, 'dataForUpload', up.data, 'rec', rec, 'cams', cams, 'calib', C.report, 'symmetry', Y.symmetry, 'crossing', Y.crossing, ...
    'rallyWindows', R.windows, ...
    'sync', X.sync, 'air', X.air, 'segs', {X.segs}, 'events', {X.events}, 'players', P, ...
    'shots', M.shots, 'rallies', M.rallies, 'summary', M.summary, 'refine', X.report);
tv.out.write(outDir, result, cfg);
end

% ======================================================================================
function s = fileStamp(f)
d = dir(f);  s = sprintf('%d-%s', d.bytes, d.date);
end

function S = probeBoth(files)
for k = 1:2, rec(k) = tv.media.probe(files{k}); end %#ok<AGROW>
% TV-SYNC-01, coarse: each file's start time (timecode, else creation time)
off = tv.util.utcSeconds(rec(2).startUtc) - tv.util.utcSeconds(rec(1).startUtc);
S.rec = rec;
S.sync = struct('startOffset', [0 off], 'delta', 0, 'drift', 0, ...
    'tref', rec(1).pts(end) / 2, 'readout', [0 0], 'shutter', 0);
end

function C = calibrate(rec, cfg)
% Every session, from the lines alone: no camera layout is assumed.
lensCfg = tv.readJson(cfg.placementFile);
lens = tv.lens.build(lensCfg.lenses, cfg.lensName, cfg.aspect);
for k = 1:2
    L = tv.lens.atResolution(lens, rec(k).width, rec(k).height);
    % RETUNE(real footage): the background should come from a quiet minute
    bg = tv.calib.background(rec(k), 61);
    [cam, rep] = tv.calib.searchPose(bg, L);
    C.cams(k) = cam;  C.bg{k} = bg;  C.report(k) = rep;
end
end

function R = findRallies(rec)
[y, fs] = tv.media.readAudio(rec(1));
[R.windows, R.onsets] = tv.rally.fromAudio(y, fs);
end

function D = detectAll(rec, C, windows, sync, cfg)
D.tracks = cell(size(windows, 1), 2);
c = tv.court.constants();
for k = 1:2
    mask = tv.detect.volumeMask(C.cams(k));
    % the largest a ball can look: the nearest point of the play volume
    pts = tv.court.playVolume(4, 8, 1);
    dmin = min(sqrt(sum((pts - C.cams(k).pos).^2, 2)));
    dpx = 2 * c.ballRadius / dmin * tv.lens.pxPerRad(C.cams(k).lens) * cfg.ballApparentScale;
    opts = struct('maxArea', max(30, pi / 4 * (2 * dpx)^2 * 3));
    for r = 1:size(windows, 1)
        f0 = tv.media.frameAt(k, windows(r, 1), rec, sync);
        f1 = tv.media.frameAt(k, windows(r, 2), rec, sync);
        cand = zeros(0, 6);
        for a = f0:cfg.chunk:f1
            first = max(0, a - 1);
            n = min(cfg.chunk + 2, f1 - first + 2);
            F = tv.media.readFrames(rec(k), first, n);
            Ck = tv.detect.ballCandidates(F, C.bg{k}, mask, opts);
            Ck(:, 1) = Ck(:, 1) + first - 1;           % 0-based absolute frame
            cand = [cand; Ck(Ck(:, 1) >= a & Ck(:, 1) < a + cfg.chunk, :)]; %#ok<AGROW>
        end
        D.tracks{r, k} = tv.track.ball2d(cand);
        D.candidates{r, k} = cand;
    end
end
end

function Y = syncAll(D, C, R, rec, sync, cfg)
all1 = [D.tracks{:, 1}];  all2 = [D.tracks{:, 2}];
% people at a few moments, as box-bottom pixels, for the twin choice
people = struct('t', {}, 'dets1', {}, 'dets2', {});
ts = linspace(R.windows(1, 1), R.windows(end, 2), 8);
for t = ts
    f = cell(1, 2);
    for k = 1:2
        img = tv.media.readFrames(rec(k), tv.media.frameAt(k, t, rec, sync), 1);
        d = tv.players.detect(img, C.bg{k}, C.cams(k), struct('heightRange', [-Inf Inf]));
        f{k} = reshape([d.box], 4, [])';
        if ~isempty(f{k}), f{k} = [f{k}(:, 1) + f{k}(:, 3) / 2, f{k}(:, 2) + f{k}(:, 4)]; end
    end
    people(end+1) = struct('t', t, 'dets1', f{1}, 'dets2', f{2}); %#ok<AGROW>
end
[Y.cams, Y.symmetry] = tv.calib.resolveSymmetry(C.cams, {all1, all2}, rec, sync, people);
Y.sync = sync;
Y.sync.delta = Y.symmetry.delta;
Y.crossing = tv.calib.crossingReport(Y.cams, struct('minDeg', cfg.minCrossDeg));
end

function X = reconstruct(D, cams, rec, sync, air, cfg)
segs = cell(size(D.tracks, 1), 1);
for r = 1:size(D.tracks, 1)
    P = tv.recon.pieces(D.tracks(r, :), rec, sync);
    segs{r} = tv.recon.segments(P, cams, rec, sync, air, cfg.CDprior);
end
opts = struct('rounds', cfg.refineRounds, 'windPrior', air.wind(1:2), 'indoor', cfg.indoor, ...
              'readoutPrior', cfg.readoutPrior);
[sync, air, segs, X.report] = tv.recon.refineSession(segs, cams, rec, sync, air, cfg.CDprior, opts);
X.events = cell(size(segs));
for r = 1:numel(segs)
    if ~isempty(segs{r}), X.events{r} = tv.events.classify(segs{r}, air); end
end
X.segs = segs;  X.sync = sync;  X.air = air;
end

function P = trackPlayers(rec, C, sync, cfg)
T = 0:1 / cfg.playerHz:rec(1).pts(end);
samples = struct('t', {}, 'dets', {});
for t = T
    dets = [];
    for k = 1:2
        n = tv.media.frameAt(k, t, rec, sync);
        img = tv.media.readFrames(rec(k), n, 1);
        dets = [dets, tv.players.detect(img, C.bg{k}, C.cams(k))]; %#ok<AGROW>
    end
    samples(end+1) = struct('t', t, 'dets', dets); %#ok<AGROW>
end
[P.tracks, P.info] = tv.players.track(samples);
P.question = any(P.info.confidence < 0.9);      % TV-PLY-07: ask once in the app
end

function P = relabel(P, label)
% TV-PLY-07: Chris answered "which one is you?" with a player label. Labels
% were given to the tracks in order (Player A, B, ...) when Chris was unknown.
k = double(label(end)) - double('A') + 1;
if k >= 1 && k <= numel(P.tracks), P.info.chris = k; P.info.confidence(k) = 1; P.question = false; end
end

function M = measure(X, R, cams, P)
[M.shots, M.rallies] = tv.metrics.rallies(X.segs, X.events, R.windows, X.air, cams, P.tracks, P.info);
M.summary = tv.metrics.session(M.shots, M.rallies, X.air);
end
