function B = errorBudget(outDir, opts)
%ERRORBUDGET  How each error source degrades the shot measurements, one at a time (Chris, 16 Nov).
%   errorBudget('out/errorbudget') flies one synthetic singles session (about 40 shots, with
%   the truth model the fitter does not share: tv.synth.studySession) and reconstructs it again
%   and again, changing ONE error source per run while the others stay at zero:
%     sync         camera 2's clock offset error: 0, 0.25, 0.5, 1, 2 ms
%     calibration  camera pose error, as image shift: 0, 0.5, 1, 2 px (a rotation of that size)
%     detection    detector noise on the ball's centre: 0, 0.25, 0.5, 1 px
%     ball size    the ball's width at the far corner: 3, 4, 5, 7 px (4 px is layout 1 at 4K,
%                  about 3.3 px layout 2; 7 px about 8K60). Made by scaling the image size,
%                  with misses rising for small balls (see below)
%     frame rate   120 and 240 fps
%   With every source at zero, what is left is the model mismatch (the truth's spin decay,
%   changing lift, per-shot drag, gusts) and the 0.3 px floor of detector noise kept in every
%   run except the detection sweep's own zero.
%   The reconstruction is the pipeline's (pieces, flights with their splits and merges, events,
%   shot metrics) with the timing and air fixed at the truth plus the error under study: the
%   session-wide refinement (TV-SYNC-03) is left out, because it would partly absorb the error
%   being measured.
%   Writes errorbudget.md, errorbudget.csv and one PNG per source (MATLAB), and returns B.
%   ASSUMPTIONS (SYNTHETIC): misses 5% plus 10% per pixel below 4 px; detector noise 0.3 px when
%   not under study; calibration error as a pure rotation.
if nargin < 1, outDir = fullfile(pwd, 'out', 'errorbudget'); end
if nargin < 2, opts = struct(); end
d = struct('seed', 11, 'minutes', 8, 'targetShots', 40, 'baseNoisePx', 0.3);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
S = tv.synth.studySession(opts.seed, struct('minutes', opts.minutes, 'targetShots', opts.targetShots));
fprintf('error budget: %d shots in %d rallies\n', numel(S.shots), numel(S.pieces));
sweeps = { ...
    'sync',        'ms', [0 0.25 0.5 1 2]; ...
    'calibration', 'px', [0 0.5 1 2]; ...
    'detection',   'px', [0 0.25 0.5 1]; ...
    'ball size',   'px', [3 4 5 7]; ...
    'frame rate',  'fps', [120 240]};
B.rows = [];
for w = 1:size(sweeps, 1)
    for lv = sweeps{w, 3}
        t = tic;
        r = oneRun(S, sweeps{w, 1}, lv, opts);
        r.source = sweeps{w, 1};  r.unit = sweeps{w, 2};  r.level = lv;  r.seconds = toc(t);
        fprintf('%-12s %5g %-3s found %3.0f%%  bounce %5.1f cm  net %5.1f cm  speed %4.2f mph  spin %5.1f cm  (%.0f s)\n', ...
            r.source, lv, r.unit, 100 * r.found, 100 * r.bounceMed, 100 * r.netMed, r.speedMedMph, 100 * r.spinMed, r.seconds);
        B.rows = [B.rows; orderfields(r)]; %#ok<AGROW>
    end
end
writeOut(B, sweeps, outDir, numel(S.shots));
end

function r = oneRun(S, source, level, opts)
sc = tv.synth.defaultScenario();
scale = 1;  noise = opts.baseNoisePx;  dropout = 0.05;  syncErr = 0;  calibPx = 0;
switch source
    case 'sync',        syncErr = level / 1000;
    case 'calibration', calibPx = level;
    case 'detection',   noise = level;
    case 'ball size',   scale = level / 4;  dropout = 0.05 + 0.10 * max(0, 4 - level);
    case 'frame rate',  sc.fps = level * 1000 / 1001;
end
sc.frameSize = round([3840 2160] * scale);
cams = tv.synth.cameras(sc);
camsCal = cams;
if calibPx > 0
    rotDeg = rad2deg(calibPx / tv.lens.pxPerRad(cams(1).lens));
else
    rotDeg = 0;
end
O = tv.synth.observe(S, cams, struct('sigmaPx', noise, 'dropout', dropout, 'posErrM', 0, 'rotErrDeg', rotDeg));
if calibPx > 0, camsCal = O.cams; end
sync = tv.synth.truthSync(cams, O.sync0);
sync.delta = sync.delta + syncErr;
air = tv.physics.defaultParams();
air.rho = S.air.rho;  air.wind = S.air.wind;                     % the mean truth wind (gusts stay unknown)
prior = struct('CD', 0.507, 'CDsd', 0.024);
nR = size(O.tracks, 1);  segs = cell(nR, 1);  ev = cell(nR, 1);  tracks = O.tracks;  rec = O.rec;
parfor k = 1:nR
    P = tv.recon.pieces(tracks(k, :), rec, sync);
    segs{k} = tv.recon.segments(P, camsCal, rec, sync, air, prior);
end
for k = 1:nR, if ~isempty(segs{k}), ev{k} = tv.events.classify(segs{k}, air); end, end
rows = tv.synth.scoreShots(S, segs, ev, air, camsCal);
f = [rows.found];
r.found = mean(f);
r.bounceMed = med(abs([rows.bounceErr]));   r.bounceP90 = p90(abs([rows.bounceErr]));
r.netMed = med(abs([rows.netErr]));         r.netP90 = p90(abs([rows.netErr]));
r.speedMedMph = med(abs([rows.speedErr])) * 2.23694;  r.speedP90Mph = p90(abs([rows.speedErr])) * 2.23694;
r.speedWithin2 = mean(abs([rows(f).speedErr]) * 2.23694 <= 2);
r.spinMed = med(abs([rows.spinErr]));       r.spinP90 = p90(abs([rows.spinErr]));
r.rpmMedPct = med(abs([rows.rpmErrPct]));
end

function m = med(x), x = x(isfinite(x)); m = NaN; if ~isempty(x), m = median(x); end, end
function p = p90(x), x = sort(x(isfinite(x))); p = NaN; if ~isempty(x), p = x(max(1, ceil(0.9 * numel(x)))); end, end

function writeOut(B, sweeps, outDir, nShots)
R = B.rows;
fid = fopen(fullfile(outDir, 'errorbudget.csv'), 'w');
fprintf(fid, 'source,level,unit,found,bounceMed_cm,bounceP90_cm,netMed_cm,netP90_cm,speedMed_mph,speedP90_mph,speedWithin2mph,spinMed_cm,spinP90_cm,rpmMed_pct\n');
for r = R'
    fprintf(fid, '%s,%g,%s,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.2f,%.2f,%.1f\n', r.source, r.level, r.unit, r.found, ...
        100 * r.bounceMed, 100 * r.bounceP90, 100 * r.netMed, 100 * r.netP90, r.speedMedMph, r.speedP90Mph, r.speedWithin2, ...
        100 * r.spinMed, 100 * r.spinP90, r.rpmMedPct);
end
fclose(fid);
% which source dominates each metric: the largest rise over the all-zero run, at a realistic
% level (sync 0.5 ms, calibration 1 px, detection 0.5 px, ball 4 px, 120 fps) and at the worst
realistic = struct('sync', 0.5, 'calibration', 1, 'detection', 0.5, 'ball_size', 3, 'frame_rate', 120);
metrics = {'bounceMed', 'bounce position (median)', 100, 'cm'; 'netMed', 'net clearance (median)', 100, 'cm'; ...
           'speedMedMph', 'speed (median)', 1, 'mph'; 'spinMed', 'spin effect (median)', 100, 'cm'};
L = {'# Error budget: which error matters for which measurement', ''};
L{end+1} = sprintf(['SYNTHETIC (%s). One synthetic singles session of %d shots, reconstructed once per setting with ONE error source changed and the others at zero. ', ...
    'Truth flown with the truth model (spin decay, changing lift, per-shot drag, gusts), so even the all-zero run is not perfect. ', ...
    'Detector noise 0.3 px in every run except the detection sweep. Timing and air fixed at the truth plus the error (the session-wide refinement, which would absorb part of it, is off). ', ...
    'Made by `vision/tools/errorBudget.m`.'], tv.util.nowUtc(), nShots);
L{end+1} = '';
L{end+1} = '| Source | Level | Shots found | Bounce, median / 90% (cm) | Net clearance, median / 90% (cm) | Speed, median / 90% (mph) | Speed within 2 mph | Spin effect, median / 90% (cm) | rpm, median (%) |';
L{end+1} = '|---|---|---|---|---|---|---|---|---|';
for r = R'
    L{end+1} = sprintf('| %s | %g %s | %.0f%% | %.1f / %.1f | %.1f / %.1f | %.2f / %.2f | %.0f%% | %.1f / %.1f | %.0f |', r.source, r.level, r.unit, ...
        100 * r.found, 100 * r.bounceMed, 100 * r.bounceP90, 100 * r.netMed, 100 * r.netP90, r.speedMedMph, r.speedP90Mph, ...
        100 * r.speedWithin2, 100 * r.spinMed, 100 * r.spinP90, r.rpmMedPct); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '**Which source dominates** (rise over the all-zero sync run, at a realistic level: sync 0.5 ms, calibration 1 px, detection 0.5 px, ball 3 px, 120 fps):';
L{end+1} = '';
L{end+1} = '| Measurement | Dominant source | Rise | Then | Next |';
L{end+1} = '|---|---|---|---|---|';
base = R(strcmp({R.source}, 'sync') & [R.level] == 0);
srcs = {'sync', 'calibration', 'detection', 'ball size', 'frame rate'};
for m = 1:size(metrics, 1)
    rise = zeros(1, numel(srcs));
    for s = 1:numel(srcs)
        lvl = realistic.(strrep(srcs{s}, ' ', '_'));
        x = R(strcmp({R.source}, srcs{s}) & [R.level] == lvl);
        rise(s) = (x.(metrics{m, 1}) - base.(metrics{m, 1})) * metrics{m, 3};
    end
    [v, o] = sort(rise, 'descend');
    L{end+1} = sprintf('| %s | %s | +%.2f %s | %s (+%.2f) | %s (+%.2f) |', metrics{m, 2}, srcs{o(1)}, v(1), metrics{m, 4}, ...
        srcs{o(2)}, v(2), srcs{o(3)}, v(3)); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '**Against the acceptance targets** (flagged where a setting breaks one):';
L{end+1} = '';
flags = {};
for r = R'
    tag = sprintf('%s %g %s', r.source, r.level, r.unit);
    if r.found < 0.95, flags{end+1} = sprintf('- %s: %.0f%% of shots found, under AC-06 (95%%).', tag, 100 * r.found); end %#ok<AGROW>
    if r.speedWithin2 < 0.9, flags{end+1} = sprintf('- %s: %.0f%% of speeds within 2 mph, under AC-07 (90%%).', tag, 100 * r.speedWithin2); end %#ok<AGROW>
    if r.bounceMed > 0.05, flags{end+1} = sprintf('- %s: median bounce error %.1f cm, over AC-08 (5 cm).', tag, 100 * r.bounceMed); end %#ok<AGROW>
    if r.spinMed > 0.10, flags{end+1} = sprintf('- %s: median spin-effect error %.1f cm, over AC-10 (10 cm).', tag, 100 * r.spinMed); end %#ok<AGROW>
    if r.rpmMedPct > 10, flags{end+1} = sprintf('- %s: median rpm error %.0f%%, over AC-11 (10%%).', tag, r.rpmMedPct); end %#ok<AGROW>
    if strcmp(r.source, 'calibration') && r.level > 1, flags{end+1} = sprintf('- %s: itself outside AC-04 (1 px).', tag); end %#ok<AGROW>
    if strcmp(r.source, 'sync') && r.level > 0.5, flags{end+1} = sprintf('- %s: itself outside AC-05 (0.5 ms).', tag); end %#ok<AGROW>
end
if isempty(flags), flags = {'- None.'}; end
L = [L, flags];
fid = fopen(fullfile(outDir, 'errorbudget.md'), 'w', 'n', 'UTF-8');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
if exist('OCTAVE_VERSION', 'builtin'), return; end
for s = 1:size(sweeps, 1)
    x = R(strcmp({R.source}, sweeps{s, 1}));
    fig = figure('Visible', 'off', 'Position', [0 0 900 650]);
    tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
    panel(tl, [x.level], 100 * [x.bounceMed; x.bounceP90], 'bounce position, cm', 5);
    panel(tl, [x.level], 100 * [x.netMed; x.netP90], 'net clearance, cm', NaN);
    panel(tl, [x.level], [x.speedMedMph; x.speedP90Mph], 'speed, mph', 2);
    panel(tl, [x.level], 100 * [x.spinMed; x.spinP90], 'spin effect, cm', 10);
    title(tl, sprintf('Error budget: %s (%s), SYNTHETIC', sweeps{s, 1}, sweeps{s, 2}));
    xlabel(tl, sprintf('%s, %s', sweeps{s, 1}, sweeps{s, 2}));
    exportgraphics(fig, fullfile(outDir, sprintf('errorbudget_%s.png', strrep(sweeps{s, 1}, ' ', '_'))), 'Resolution', 120);
    close(fig);
end
end

function panel(tl, lv, Y, name, target)
ax = nexttile(tl);  hold(ax, 'on');  grid(ax, 'on');
plot(ax, lv, Y(1, :), '-o', 'Color', [0.17 0.54 0.24], 'LineWidth', 1.5, 'DisplayName', 'median');
plot(ax, lv, Y(2, :), '--s', 'Color', [0.31 0.49 1.0], 'LineWidth', 1.2, 'DisplayName', '90th percentile');
if isfinite(target), yline(ax, target, ':', 'target', 'Color', [0.6 0 0], 'DisplayName', 'target'); end
title(ax, name);  legend(ax, 'Location', 'northwest');
end
