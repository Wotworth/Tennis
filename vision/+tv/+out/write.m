function write(outDir, R, cfg)
%WRITE  The session's output files (TV-OUT-01 to TV-OUT-05).
%   session.json       cameras, calibration and sync quality, air, wind,
%                      session drag, code version, identity question
%   shots.json/.csv    one record per shot, every metric
%   trajectories.json.gz  200 Hz path per shot plus its no-spin path
%   rallies.json       per rally
%   plots/*.png        bounce map, per-rally 3D, speed histogram (MATLAB only)
%   reel_1080p.mp4, clips/rally_NN.mp4   rallies only, from camera 1
%   rejects/rejects.csv, .html  everything rejected and why (TV-ADJ-06)
%   Not yet: the tracer clips (ball path drawn on the video, TV-OUT-04).
s.code = tv.util.codeVersion();
s.created = tv.util.nowUtc();
s.startUtc = R.rec(1).startUtc;
s.cameras = arrayfun(@(k) struct('serial', R.rec(k).serial, 'position', R.cams(k).pos, ...
    'lineRmsPx', R.calib(k).rmsPx, 'readoutS', R.sync.readout(k), ...
    'cornersOutOfView', {cornersMissing(R.calib(k))}, ...       % TV-CAL-20
    'lineSupport', fieldOr(R.calib(k), 'support', NaN), ...       % share of the fitted lines with paint under them (Chris, 20 Nov)
    'calibSource', fieldOr(R.calib(k), 'source', 'lines')), 1:2);   % 'lines', or 'corners' when tapped
s.sync = struct('startOffsetS', R.sync.startOffset(2), 'deltaS', R.sync.delta, 'drift', R.sync.drift);
s.air = struct('rho', R.air.rho, 'wind', R.air.wind(1:2), 'sessionCD', R.air.sessionCD, 'gustExcess10', NaN, 'windLevel', 'unknown');
if isfield(R.air, 'gustExcess10'), s.air.gustExcess10 = R.air.gustExcess10; end
if isfield(R, 'shots') && isstruct(R.shots) && ~isempty(R.shots) && isfield(R.shots, 'windLevel'), s.air.windLevel = R.shots(1).windLevel; end   % 22 Nov, item 10: the app marks the curve less certain when 'gusty'
s.symmetry = struct('chosen', R.symmetry.chosen, 'ballGapM', R.symmetry.ballGap', 'playerGapM', R.symmetry.playerGap', ...
    'cam2AtLowerX', R.symmetry.cam2AtLowerX);
s.crossing = struct('minDeg', R.crossing.minDeg, 'thresholdDeg', R.crossing.thresholdDeg, ...
    'zones', R.crossing.zones, 'low', {R.crossing.low}, 'text', R.crossing.text);
s.identity = struct('chrisTrack', R.players.info.chris, 'confidence', R.players.info.confidence, ...
    'question', R.players.question);
s.counts = struct('rallies', numel(R.rallies), 'shots', numel(R.shots));
% TV-ADJ-06: what was not analysed, and why; the full log uploads as rejects/
s.rejects = struct('report', 'rejects/rejects.html', 'csv', 'rejects/rejects.csv', 'counts', ...
    tv.out.rejects(outDir, R.gateLog, R.dropped, R.players.rejected));
s.summary = R.summary;
% Chris, 20 Nov: every frame searched; what finding rallies by sound alone would have skipped
if isfield(R, 'rallyFinding')
    f = R.rallyFinding;
    s.rallyFinding = struct('mode', f.mode, 'playSeconds', f.playSeconds, 'soundCoverage', f.soundCoverage, ...
        'soundWindows', f.soundWindows, 'windows', R.rallyWindows);
end
tv.util.writeJson(fullfile(outDir, 'session.json'), s);
tv.util.writeJson(fullfile(outDir, 'shots.json'), R.shots);
tv.util.writeJson(fullfile(outDir, 'rallies.json'), R.rallies);
writeCsv(fullfile(outDir, 'shots.csv'), R.shots);
writeTrajectories(fullfile(outDir, 'trajectories.json'), R);
if cfg.outputs.plots && ~exist('OCTAVE_VERSION', 'builtin'), tv.out.plots(outDir, R); end
if cfg.outputs.reel, tv.out.reel(outDir, R); end
end

function writeCsv(file, shots)
if isempty(shots), fid = fopen(file, 'w'); fclose(fid); return; end
f = fieldnames(shots);
keep = f(arrayfun(@(i) isscalar(shots(1).(f{i})) || ischar(shots(1).(f{i})), 1:numel(f)));
fid = fopen(file, 'w');
fprintf(fid, '%s\n', strjoin(keep', ','));
for s = shots'
    vals = cellfun(@(n) fmt(s.(n)), keep, 'UniformOutput', false);
    fprintf(fid, '%s\n', strjoin(vals', ','));
end
fclose(fid);
end

function v = fmt(x)
if ischar(x), v = ['"' x '"'];
elseif islogical(x), v = sprintf('%d', x);
else, v = sprintf('%.6g', x); end
end

function writeTrajectories(file, R)
c = tv.court.constants();
T = [];
for s = R.shots'
    segs = R.segs{s.rally};
    i = find(arrayfun(@(g) abs(g.t0 - s.t) < 0.06 || (s.t >= g.t0 && s.t <= max(g.t)), segs), 1);
    if isempty(i), continue; end
    g = segs(i);
    tt = (s.t:0.005:s.t + s.flightTime)';
    if numel(tt) < 2, continue; end
    P = tv.recon.segmentModel(g.x, g.t0, max(tt, g.t0), R.air);
    q = R.air;  q.CD = g.x(9);  q.CL = 0;
    [~, P0] = tv.physics.simulate(g.x(1:3), g.x(4:6), q, 4, 0.005, c.ballRadius);
    T = [T; struct('rally', s.rally, 'shot', s.index, 't0', tt(1), 'dt', 0.005, ...
        'xyz', round(P * 1000) / 1000, 'noSpin', round(P0 * 1000) / 1000)]; %#ok<AGROW>
end
tv.util.writeJson(file, T);
gzip(file);  delete(file);
end

function m = cornersMissing(rep)
m = {};
if isfield(rep, 'corners') && ~isempty(rep.corners), m = rep.corners.missing(:)'; end
end

function v = fieldOr(s, f, d)
v = d;
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); end
end
