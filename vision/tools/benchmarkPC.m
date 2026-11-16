function R = benchmarkPC(opts)
%BENCHMARKPC  Day-one benchmark of the closet PC, before any camera or court exists (Chris, 16 Nov).
%   benchmarkPC() makes synthetic two-camera footage, runs the whole pipeline on it, times
%   every stage, and projects the hours a real 2-hour session would take, against the
%   12-hour limit (6 hours is the goal; TV-OPS-04):
%     1. 4K120, 26 s of footage (two rallies, nine shots), with the GPU power cap;
%     2. the same without the cap (scheduled task "TennisVision GPU uncapped", made by the
%        setup script; the capped task runs again afterwards), to show what the cap costs;
%     3. 4K240, 13 s (one rally), with the cap.
%   Temperatures and GPU power are logged every minute. The result goes to
%   C:\TennisVision\benchmark\benchmark.md, to the screen, and to the phone (ntfy) when
%   config/tennisvision.json exists. It takes about an hour or two: making 4K footage is
%   itself slow (MATLAB draws every frame), and is not part of the timings.
%   opts.quick = true: quarter resolution, 4K120 only, no cap comparison (CI smoke test).
%   opts.outDir, opts.realShots (550: a 2-hour session), opts.realRallyFraction (0.25).
if nargin < 1, opts = struct(); end
d = struct('quick', false, 'outDir', defaultOut(), 'realShots', 550, 'realRallyFraction', 0.25, 'capCompare', ispc());
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if opts.quick, opts.capCompare = false; end
if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
cfgPC = pcConfig();
logs = fullfile(opts.outDir, 'logs');
tl = [];
if ispc(), tl = tv.ops.tempLogger(struct('logs', logs, 'tempLogS', 60)); end
cleanup = onCleanup(@() stopTimer(tl));

runs = struct('name', {}, 'P', {}, 'stageS', {}, 'totalS', {}, 'genS', {});
modes = {'4K120', 26, 120000 / 1001};
if ~opts.quick, modes(end+1, :) = {'4K240', 13, 240000 / 1001}; end
for m = 1:size(modes, 1)
    caps = {'capped'};
    if opts.capCompare && m == 1, caps{end+1} = 'uncapped'; end %#ok<AGROW>
    for c = 1:numel(caps)
        name = sprintf('%s %s', modes{m, 1}, caps{c});
        fprintf('\n=== %s ===\n', name);
        if strcmp(caps{c}, 'uncapped'), schtask('TennisVision GPU uncapped'); end
        runs(end+1) = oneRun(name, modes{m, 2}, modes{m, 3}, opts); %#ok<AGROW>
        if strcmp(caps{c}, 'uncapped'), schtask('TennisVision GPU cap'); end
    end
end
R.runs = runs;
R.peaks = tv.ops.tempPeaks(logs, 2);
R.text = report(runs, R.peaks, opts, cfgPC);
fid = fopen(fullfile(opts.outDir, 'benchmark.md'), 'w', 'n', 'UTF-8');  fprintf(fid, '%s\n', R.text);  fclose(fid);
fprintf('\n%s\n', R.text);
if ~isempty(cfgPC) && isfield(cfgPC, 'notify')
    cfgPC.notify('Benchmark done', summaryLine(runs));
end
end

function r = oneRun(name, seconds, fps, opts)
sc = tv.synth.defaultScenario();
sc.fps = fps;  sc.duration = seconds;
sc.rallies = sc.rallies(arrayfun(@(x) x.start < seconds - 4, sc.rallies));
if opts.quick, sc.frameSize = [960 540]; else, sc.frameSize = [3840 2160]; sc.ballDrawScale = 1; end
dir0 = fullfile(opts.outDir, strrep(name, ' ', '-'));
if exist(dir0, 'dir'), rmdir(dir0, 's'); end
t = tic;
G = tv.synth.generate(fullfile(dir0, 'synth'), sc);
r.genS = toc(t);
fprintf('footage made in %.0f s (not timed below)\n', r.genS);
cfg = tv.pipeline.defaults();
cfg.ballApparentScale = sc.ballDrawScale;
cfg.weather = struct('tempC', sc.weather.tempC, 'relHumidity', sc.weather.relHumidity, ...
    'pressurePa', sc.weather.pressurePa, 'wind10', 2 * sc.wind(1:2));
cfg.readoutPrior = mean(sc.readout);
cfg.notify = @(a, b) fprintf('[alert] %s: %s\n', a, b);
out = fullfile(dir0, 'out');
t = tic;
res = tv.pipeline.run(G.files, out, cfg);
r.totalS = toc(t);
r.stageS = struct();
M = dir(fullfile(out, 'stages', '*.manifest.json'));
for f = M(:)'
    j = jsondecode(fileread(fullfile(f.folder, f.name)));
    if isfield(j, 'seconds'), r.stageS.(j.stage) = j.seconds; end
end
r.stageS.outputs = max(0, r.totalS - sum(cell2mat(struct2cell(r.stageS))));
synth = struct('durationS', seconds, 'rallyS', sum(diff(res.rallyWindows, 1, 2)), 'shots', max(1, numel(res.shots)));
real = struct('durationS', 7200, 'rallyS', opts.realRallyFraction * 7200, 'shots', opts.realShots);
r.P = tv.ops.projectHours(r.stageS, synth, real);
r.name = name;
r = orderfields(r, {'name', 'P', 'stageS', 'totalS', 'genS'});
end

function t = report(runs, peaks, opts, cfgPC)
L = {'# Closet PC benchmark', ''};
L{end+1} = sprintf('%s. SYNTHETIC footage, timed stage by stage, projected to a 2-hour session (%d shots, %.0f%% of the time in rallies). Limit 12 h, goal 6 h (TV-OPS-04).', ...
    tv.util.nowUtc(), opts.realShots, 100 * opts.realRallyFraction);
L{end+1} = '';
L{end+1} = ['| Stage | ' strjoin({runs.name}, ' | ') ' |'];
L{end+1} = ['|---' repmat('|---', 1, numel(runs)) '|'];
stages = runs(1).P.table(:, 1);
for i = 1:numel(stages)
    cells = arrayfun(@(r) sprintf('%.2f h (%.0f s here)', r.P.table{i, 4}, r.P.table{i, 2}), runs, 'UniformOutput', false);
    L{end+1} = ['| ' stages{i} ' | ' strjoin(cells, ' | ') ' |']; %#ok<AGROW>
end
tot = arrayfun(@(r) sprintf('**%.1f h** (%s)', r.P.totalH, verdict(r.P.totalH)), runs, 'UniformOutput', false);
L{end+1} = ['| **2-hour session** | ' strjoin(tot, ' | ') ' |'];
L{end+1} = '';
cap = strcmp({runs.name}, '4K120 capped');  unc = strcmp({runs.name}, '4K120 uncapped');
if any(cap) && any(unc)
    a = runs(cap).P.totalH;  b = runs(unc).P.totalH;
    L{end+1} = sprintf('The GPU power cap costs %.0f%% in time on 4K120 (%.1f h capped, %.1f h without).', 100 * (a / b - 1), a, b);
    if any(strcmp({runs.name}, '4K240 capped'))
        L{end+1} = sprintf('4K240 without the cap: about %.1f h (scaled by the same ratio).', runs(strcmp({runs.name}, '4K240 capped')).P.totalH * b / a);
    end
end
if ~isempty(cfgPC), L{end+1} = sprintf('Power cap setting: %d W.', cfgPC.pc.gpuPowerCapW); end
if isfinite(peaks.cpu) || isfinite(peaks.gpu)
    L{end+1} = sprintf('Peak temperatures during the benchmark: CPU %.0f C, GPU %.0f C.', peaks.cpu, peaks.gpu);
end
L{end+1} = '';
L{end+1} = 'Scaling: probe, rally finding and player tracking with the footage length; calibration once; detection, sync and outputs with the time in rallies; flights and metrics with the number of shots. Real footage will differ (TV-PH-2 measures it per capture mode).';
t = strjoin(L, newline);
end

function s = verdict(h)
if h <= 6, s = 'within the 6 h goal'; elseif h <= 12, s = 'within the 12 h limit'; else, s = 'OVER the 12 h limit'; end
end

function s = summaryLine(runs)
s = strjoin(arrayfun(@(r) sprintf('%s %.1f h', r.name, r.P.totalH), runs, 'UniformOutput', false), ', ');
s = [s ' for a 2-hour session (limit 12 h). Details: C:\TennisVision\benchmark\benchmark.md'];
end

function schtask(name)
[st, out] = tv.util.shell(sprintf('schtasks /run /tn "%s"', name));
if st ~= 0, warning('benchmark:task', 'Could not start "%s" (run the setup script first): %s', name, out); end
pause(5);
end

function cfg = pcConfig()
cfg = [];
f = fullfile(fileparts(mfilename('fullpath')), '..', 'config', 'tennisvision.json');
if exist(f, 'file'), cfg = tv.ingest.loadConfig(f); end
end

function o = defaultOut()
if ispc(), o = 'C:\TennisVision\benchmark'; else, o = fullfile(pwd, 'out', 'benchmark'); end
end

function stopTimer(tl)
if ~isempty(tl), stop(tl); delete(tl); end
end
