function R = fitStudy(outDir, opts)
%FITSTUDY  The flight fit against truth it was not built from, over a whole session (TV-TST-01).
%   fitStudy('out/fitstudy') generates a synthetic 90-minute singles session
%   of about 400 shots (tv.synth.studySession: spin decay, C_L following the
%   spin parameter with per-shot scatter, per-shot C_D, wind gusts, ode45),
%   simulates what each 4K camera's detector reports (tv.synth.observe: clock
%   offset and drift, rolling shutter, 0.5 px noise, misses, the ball hidden
%   at contacts, calibration-sized pose errors), then runs the pipeline's
%   own reconstruction: pieces, flights, session timing and wind, events,
%   shot metrics. No video is rendered (that is pipelineTest's job).
%   Writes fitstudy.md (medians and 90th percentiles) and fitstudy_shots.csv.
%   opts: seed, minutes, targetShots, rounds (refineSession), syncRallies.
%   20 Nov (Chris: compare detectors on hundreds of shots; Tuesday's set-up; sideways curve):
%   opts.scenario 'tuesday': Linear lens, 4K at 240 frames a second, cameras 2.5 m behind the
%     baselines on a side fence 4 m out at 3.5 m (docs/reports/TV-PH-0a.md), the ball about
%     4 px across at the far corner.
%   opts.errModel: a detector's measured recall and centre error by ball size
%     (tv.synth.detectorModel) instead of the flat 0.5 px and 5% misses.
%   opts.sideSpin, opts.machine: tv.synth.studySession's sidespin and ball-machine feeds.
%   opts.gustAmp: the gusts' amplitude per period, m/s (0: calm, steady wind only).
%   opts.tag: names the outputs fitstudy_<tag>.md / .csv; opts.title: a line for the report.
if nargin < 1, outDir = fullfile(pwd, 'out', 'fitstudy'); end
if nargin < 2, opts = struct(); end
d = struct('seed', 7, 'minutes', 90, 'targetShots', 400, 'rounds', 3, 'syncRallies', 3, ...
    'scenario', 'default', 'errModel', [], 'sideSpin', false, 'machine', 0, 'tag', '', 'title', '', 'gustAmp', 0.6);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
t0 = tic;
sc = tv.synth.defaultScenario();  sc.frameSize = [3840 2160];
if strcmp(opts.scenario, 'tuesday')
    c0 = tv.court.constants();
    sc.lensName = 'Linear';  sc.mountX = c0.halfLength + 2.5;  sc.standoff = 4;  sc.mountHeight = 3.5;
    sc.fps = 240000 / 1001;
end
camsTrue = tv.synth.cameras(sc);
S = tv.synth.studySession(opts.seed, struct('minutes', opts.minutes, 'targetShots', opts.targetShots, ...
    'sideSpin', opts.sideSpin, 'machine', opts.machine, 'gustAmp', opts.gustAmp));
O = tv.synth.observe(S, camsTrue, struct('errModel', opts.errModel));
R.farBallPx = farBall(camsTrue);
fprintf('fit study %s: the ball is %.1f px across at the far corner\n', opts.tag, R.farBallPx);
fprintf('fit study: %d shots in %d rallies, generated in %.0f s\n', numel(S.shots), numel(S.pieces), toc(t0));
cfg = tv.pipeline.defaults();
air = tv.physics.defaultParams();
air.rho = S.air.rho;                                          % weather from the forecast: temperature etc. right
wind10 = 2 * S.air.wind(1:2) + [0.8 -0.5];                    % the forecast wind, not the truth
air.wind = [0.5 * wind10, 0];
rec = O.rec;  cams = O.cams;  sync = O.sync0;
% medium sync: offset and drift from the sight lines, window by window (as tv.pipeline.run)
[sync, R.clock] = tv.sync.clockLine(O.tracks, cams, rec, sync);
fprintf('medium sync: offset %.2f ms, drift %.1f ppm from %d windows\n', 1000 * sync.delta, 1e6 * sync.drift, numel(R.clock.t));
% flights per rally (independent: parallel where the Parallel Computing Toolbox is installed)
nR = size(O.tracks, 1);  segs = cell(nR, 1);  tracks = O.tracks;  prior = cfg.CDprior;
parfor r = 1:nR
    P = tv.recon.pieces(tracks(r, :), rec, sync);
    segs{r} = tv.recon.segments(P, cams, rec, sync, air, prior);
end
fprintf('flights fitted in %.0f s\n', toc(t0));
ro = struct('rounds', opts.rounds, 'windPrior', air.wind(1:2), 'indoor', false, 'readoutPrior', cfg.readoutPrior);
[sync, air, segs, rep] = tv.recon.refineSession(segs, cams, rec, sync, air, cfg.CDprior, ro);
fprintf('session refined in %.0f s\n', toc(t0));
ev = cell(nR, 1);
for r = 1:nR, if ~isempty(segs{r}), ev{r} = tv.events.classify(segs{r}, air); end, end

% the first rallies' events next to the truth, for checking by eye in the CI log
for r = 1:min(3, nR)
    tr = S.shots([S.shots.rally] == r);
    fprintf('rally %d truth: %s\n', r, strjoin(arrayfun(@(s) sprintf('hit %.3f%s', s.tHit, ...
        tv.testing.ternary(isnan(s.tBounce), '', sprintf(' bounce %.3f', s.tBounce))), tr, 'UniformOutput', false), ', '));
    if ~isempty(ev{r}), fprintf('rally %d found: %s\n', r, strjoin(arrayfun(@(e) sprintf('%s %.3f', e.type, e.t), ev{r}, 'UniformOutput', false), ', ')); end
    if ~isempty(segs{r}), fprintf('rally %d flights: %s\n', r, strjoin(arrayfun(@(g) sprintf('%.3f-%.3f (%.2f px)', min(g.t), max(g.t), g.rmsPx), segs{r}, 'UniformOutput', false), ', ')); end
end

rows = tv.synth.scoreShots(S, segs, ev, air, cams);
% every shot not found, with what was found near it, so the CI log says why
for k = find(~[rows.found])
    s = S.shots(k);  r = s.rally;  near = '';
    if ~isempty(ev{r})
        [~, o] = sort(abs([ev{r}.t] - s.tHit));  o = o(1:min(3, end));
        near = strjoin(arrayfun(@(e) sprintf('%s %+.0f ms', e.type, 1000 * (e.t - s.tHit)), ev{r}(o), 'UniformOutput', false), ', ');
    end
    g = '';
    if ~isempty(segs{r})
        t0s = arrayfun(@(x) min(x.t), segs{r});  [~, j] = min(abs(t0s - s.tHit));
        g = sprintf('nearest flight starts %+.0f ms', 1000 * (t0s(j) - s.tHit));
    end
    fprintf('missed: rally %d shot %d (%s%s, setting %d, hit %.3f): %s; %s\n', r, s.index, s.kind, ...
        tv.testing.ternary(s.isServe, ', serve', ''), rows(k).setting, s.tHit, near, g);
end
R.rows = rows;  R.sync = sync;  R.air = air;  R.report = rep;
% timing at mid-session, middle row (as tv.synth.compare)
n = round(rec(2).nFrames / 2);  vMid = rec(2).height / 2;
tPipe = tv.recon.detTimes(2, n, vMid, rec, sync) - sync.shutter / 2;
clock2 = camsTrue(2).recordStart + rec(2).pts(n + 1) + camsTrue(2).readout * (vMid - 1) / rec(2).height;
R.syncErrMs = 1000 * (tPipe - (tv.synth.truthTime(camsTrue(2), clock2) - tv.synth.truthTime(camsTrue(1), camsTrue(1).recordStart)));
R.readoutErrMs = 1000 * (sync.readout - [camsTrue.readout]);
R.seconds = toc(t0);
R.opts = opts;
writeOut(R, S, outDir);
end

function px = farBall(cams)
% the ball's diameter in px at the far doubles corner from camera 1
c = tv.court.constants();
P = [c.halfLength, -c.halfDoubles, 0.5];
px = 2 * c.ballRadius / norm(P - cams(1).pos) * tv.lens.pxPerRad(cams(1).lens);
end

function writeOut(R, S, outDir)
rows = R.rows;
f = [rows.found];
inCall = ismember({rows.truthCall}, {'in', 'out'});
callable = f & (inCall | strcmp({rows.truthCall}, 'net'));
callOk = callable & strcmp({rows.call}, {rows.truthCall});
short = [rows.shortAfterBounce];
L = {};
L{end+1} = '# Fit study: the flight fit against truth it was not built from';
L{end+1} = '';
if ~isempty(R.opts.title), L{end+1} = R.opts.title; L{end+1} = ''; end
L{end+1} = sprintf('Far-corner ball %.1f px across.', R.farBallPx);
L{end+1} = '';
L{end+1} = sprintf('SYNTHETIC. %d shots in %d rallies (90-minute singles session, 4K cameras, %s). Truth flights: ode45, spin decay (5 s), C_L following the spin parameter with 15%% per-shot scatter, per-shot C_D (sd 0.024), wind gusts (%s). The fitter assumes none of these. Run time %.0f min.', ...
    numel(rows), numel(S.pieces), noiseText(R.opts), tv.testing.ternary(R.opts.gustAmp > 0, sprintf('%.1f m/s on each of three periods', R.opts.gustAmp), 'none: calm, steady wind only'), R.seconds / 60);
L{end+1} = '';
L{end+1} = '| Measure | Shots | Median | 90th percentile | Target |';
L{end+1} = '|---|---|---|---|---|';
L{end+1} = sprintf('| Shots found (hit within 30 ms) | %d of %d | | | 95%% (AC-06) |', nnz(f), numel(rows));
L{end+1} = line('Hit time error, ms', abs([rows.hitDtMs]), '', 1);
L{end+1} = line('Speed at contact error, mph', abs([rows.speedErr]) * 2.23694, '2 mph for 90% (AC-07)', 2);
L{end+1} = line('Bounce position error, cm', [rows.bounceErr] * 100, 'median 5 cm (AC-08)', 1);
L{end+1} = line('Spin effect error, cm', abs([rows.spinErr]) * 100, '10 cm (AC-10)', 1);
L{end+1} = line('Net clearance error, cm', abs([rows.netErr]) * 100, '3-5 cm (spec estimate)', 1);
cv = [rows.curveTrue];
if any(isfinite(cv) & abs(cv) > 0.01)
    L{end+1} = line('Sideways curve from spin, error, cm (shots that bounced)', abs([rows.curveErr]) * 100, '', 1);
    big = abs(cv) >= 0.15;
    L{end+1} = line('Sideways curve error, cm, shots curving 0.5 ft or more', abs([rows(big).curveErr]) * 100, '', 1);
    shown = abs([rows.curveFound]) >= 0.15;  truthBig = abs(cv) >= 0.15;  ok = isfinite([rows.curveFound]);
    L{end+1} = sprintf('| Curve shown (0.5 ft or more) when it truly is / when it truly is not | %d of %d / %d of %d | | | |', ...
        nnz(shown & truthBig & ok), nnz(truthBig & ok), nnz(shown & ~truthBig & ok), nnz(~truthBig & ok));
    % other showing limits (the app's curveShowFt), and how often a shown curve is on the wrong side
    cf = [rows.curveFound];
    for ft = [1 1.5 2]
        lim = ft * 0.3048;  sh = abs(cf) >= lim & ok;  tb = abs(cv) >= lim;  under = abs(cv) < 0.15;
        L{end+1} = sprintf(['| Limit %.1f ft: shown when truly over it / when truly under 0.5 ft / shown on the wrong side | ' ...
            '%d of %d / %d of %d / %d | | | |'], ft, nnz(sh & tb), nnz(tb & ok), nnz(sh & under), nnz(under & ok), ...
            nnz(sh & sign(cf) ~= sign(cv))); %#ok<AGROW>
    end
    L{end+1} = sprintf('| Limit 0.5 ft: shown on the wrong side | %d of %d shown | | | |', nnz(shown & ok & sign(cf) ~= sign(cv)), nnz(shown & ok));
end
L{end+1} = line('rpm error, %', abs([rows.rpmErrPct]), '(rpm +/-25% shown, TV-SPN-03)', 0);
L{end+1} = line('rpm error with the true lift known, %', abs([rows.rpmKnownClPct]), '10% (AC-11)', 0);
L{end+1} = sprintf('| In / out / net calls right | %d of %d | | | all |', nnz(callOk), nnz(callable));
L{end+1} = line('Bounce error after a short flight (< 0.25 s to the next hit), cm', [rows(short).bounceErr] * 100, '', 1);
L{end+1} = line('Bounce error, all other shots, cm', [rows(~short).bounceErr] * 100, '', 1);
L{end+1} = '';
L{end+1} = sprintf('Clock drift found %.1f ppm (truth 40). Session timing error at mid-session: %.2f ms. Readout time error: camera 1 %.2f ms, camera 2 %.2f ms. Wind found %s m/s (mean truth %s, gusts not modelled by the fit). Session C_D %.3f.', ...
    1e6 * R.sync.drift, R.syncErrMs, R.readoutErrMs(1), R.readoutErrMs(2), mat2str(round(R.air.wind(1:2) * 10) / 10), mat2str(S.air.wind(1:2)), median([S.shots.CD]));
% ball-machine settings: how alike the repeats look (spread of what the system measured, and the truth's)
st = [rows.setting];
if any(st > 0)
    L{end+1} = '';
    L{end+1} = '| Machine setting | Feeds found | Speed spread found (truth), mph sd | Spin effect spread found, cm sd | Landing spread found (truth), cm sd |';
    L{end+1} = '|---|---|---|---|---|';
    for k = unique(st(st > 0))
        g = rows(st == k & f);
        tr = S.shots([S.shots.setting] == k);
        % the machine feeds from either end: landings are measured from its own end (x mirrored)
        eg = arrayfun(@(s) sign(s.pHit(1)), S.shots(st == k & f));  et = arrayfun(@(s) sign(s.pHit(1)), tr);
        bf = reshape([g.bounceFound], 2, [])';  bf(:, 1) = -eg(:) .* bf(:, 1);  bf = bf(all(isfinite(bf), 2), :);
        bt = reshape([tr.pBounce], 3, [])';  bt(:, 1) = -et(:) .* bt(:, 1);  bt = bt(all(isfinite(bt), 2), 1:2);
        L{end+1} = sprintf('| %d | %d of %d | %.2f (%.2f) | %.1f | %.1f (%.1f) |', k, numel(g), numel(tr), ...
            2.23694 * std([g.speedFound], 'omitnan'), 2.23694 * std([tr.speedHit]), 100 * std([g.spinFound], 'omitnan'), ...
            100 * sqrt(sum(var(bf, 0, 1))), 100 * sqrt(sum(var(bt, 0, 1)))); %#ok<AGROW>
    end
end
base = 'fitstudy';  if ~isempty(R.opts.tag), base = ['fitstudy_' R.opts.tag]; end
fid = fopen(fullfile(outDir, [base '.md']), 'w', 'n', 'UTF-8');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
fid = fopen(fullfile(outDir, [base '_shots.csv']), 'w');
fprintf(fid, 'rally,index,kind,serve,truthCall,call,found,hitDtMs,speedErr_mps,bounceErr_m,spinErr_m,netErr_m,rpmErrPct,rpmKnownClPct,shortAfterBounce,toNextHit_s,bounceSegN,bounceSegS,rmsPx,curveErr_m,curveTrue_m,setting\n');
for r = rows'
    fprintf(fid, '%d,%d,%s,%d,%s,%s,%d,%.2f,%.3f,%.4f,%.4f,%.4f,%.1f,%.1f,%d,%.3f,%g,%.3f,%.2f,%.4f,%.4f,%d\n', r.rally, r.index, r.kind, r.serve, ...
        r.truthCall, r.call, r.found, r.hitDtMs, r.speedErr, r.bounceErr, r.spinErr, r.netErr, r.rpmErrPct, r.rpmKnownClPct, r.shortAfterBounce, ...
        r.toNextHit, r.bounceSegN, r.bounceSegS, r.rms, r.curveErr, r.curveTrue, r.setting);
end
fclose(fid);
end

function s = line(name, x, target, dec)
x = x(isfinite(x));
if isempty(x), s = sprintf('| %s | 0 | | | %s |', name, target); return; end
x = sort(x);  p90 = x(max(1, ceil(0.9 * numel(x))));
fmt = sprintf('| %%s | %%d | %%.%df | %%.%df | %%s |', dec, dec);
s = sprintf(fmt, name, numel(x), median(x), p90, target);
end

function t = noiseText(o)
if isempty(o.errModel), t = '0.5 px detector noise, 5% of frames missed';
else, t = sprintf('detector "%s" as measured by ball size (tools/detectorSizeStudy.m)', o.errModel.name); end
if strcmp(o.scenario, 'tuesday'), t = [t ', Linear lens at 240 frames a second']; end
end
