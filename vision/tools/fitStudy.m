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
if nargin < 1, outDir = fullfile(pwd, 'out', 'fitstudy'); end
if nargin < 2, opts = struct(); end
d = struct('seed', 7, 'minutes', 90, 'targetShots', 400, 'rounds', 3, 'syncRallies', 3);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
t0 = tic;
sc = tv.synth.defaultScenario();  sc.frameSize = [3840 2160];
camsTrue = tv.synth.cameras(sc);
S = tv.synth.studySession(opts.seed, struct('minutes', opts.minutes, 'targetShots', opts.targetShots));
O = tv.synth.observe(S, camsTrue);
fprintf('fit study: %d shots in %d rallies, generated in %.0f s\n', numel(S.shots), numel(S.pieces), toc(t0));
cfg = tv.pipeline.defaults();
air = tv.physics.defaultParams();
air.rho = S.air.rho;                                          % weather from the forecast: temperature etc. right
wind10 = 2 * S.air.wind(1:2) + [0.8 -0.5];                    % the forecast wind, not the truth
air.wind = [0.5 * wind10, 0];
rec = O.rec;  cams = O.cams;  sync = O.sync0;
% medium sync from the first rallies' sight lines (tv.pipeline.run does this over the whole clip)
nr = min(opts.syncRallies, size(O.tracks, 1));
all1 = [O.tracks{1:nr, 1}];  all2 = [O.tracks{1:nr, 2}];
sync.delta = tv.sync.fromRays({all1, all2}, cams, rec, sync);
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

% --- compare, shot by shot -------------------------------------------------------------
mcfg = struct('cams', cams, 'lines', 'singles');  info = struct('chris', 0);
rows = [];
for s = S.shots'
    row = struct('rally', s.rally, 'index', s.index, 'kind', s.kind, 'serve', s.isServe, 'truthCall', s.result, ...
        'shortAfterBounce', s.shortFlight, 'toNextHit', s.toNextHit, 'found', false, 'hitDtMs', NaN, ...
        'speedErr', NaN, 'bounceErr', NaN, 'spinErr', NaN, 'netErr', NaN, 'rpmErrPct', NaN, 'call', '', ...
        'bounceSegN', NaN, 'bounceSegS', NaN, 'rms', NaN);
    E = ev{s.rally};  G = segs{s.rally};
    if isempty(E) || isempty(G), rows = [rows; row]; continue; end %#ok<AGROW>
    hits = E(strcmp({E.type}, 'hit'));
    [dt, i] = min(abs([hits.t] - s.tHit));
    if isempty(dt) || dt > 0.03, rows = [rows; row]; continue; end %#ok<AGROW>
    row.found = true;  row.hitDtMs = 1000 * (hits(i).t - s.tHit);
    hitEv = hits(i);
    seg = G(hitEv.segAfter);
    bEv = [];  nEv = [];  segAfter = [];
    b = E(strcmp({E.type}, 'bounce'));
    if ~isnan(s.tBounce) && ~isempty(b)
        [db, j] = min(abs([b.t] - s.tBounce));
        if db < 0.05, bEv = b(j); if bEv.segAfter > 0, segAfter = G(bEv.segAfter); end, end
    end
    nn = E(strcmp({E.type}, 'net'));
    if strcmp(s.result, 'net') && ~isempty(nn), nEv = nn(1); end
    m = tv.metrics.shot(seg, segAfter, hitEv, bEv, nEv, air, mcfg, [], info, s.isServe, sign(s.pHit(2)));
    row.speedErr = m.speedContact - s.speedHit;
    row.rms = seg.rmsPx;
    if ~isempty(bEv)
        row.bounceErr = norm(m.bounce - s.pBounce(1:2));
        row.spinErr = m.spinEffect - s.spinEffect;
        if ~isempty(segAfter), row.bounceSegN = size(segAfter.obs, 1); row.bounceSegS = max(segAfter.t) - min(segAfter.t); end
    end
    if isfinite(s.netClearance) && isfinite(m.netClearance), row.netErr = m.netClearance - s.netClearance; end
    if isfinite(m.rpm) && s.rpm0 > 0, row.rpmErrPct = 100 * (m.rpm - s.rpm0) / s.rpm0; end
    row.call = m.call;
    rows = [rows; row]; %#ok<AGROW>
end
R.rows = rows;  R.sync = sync;  R.air = air;  R.report = rep;
% timing at mid-session, middle row (as tv.synth.compare)
n = round(rec(2).nFrames / 2);  vMid = rec(2).height / 2;
tPipe = tv.recon.detTimes(2, n, vMid, rec, sync) - sync.shutter / 2;
clock2 = camsTrue(2).recordStart + rec(2).pts(n + 1) + camsTrue(2).readout * (vMid - 1) / rec(2).height;
R.syncErrMs = 1000 * (tPipe - (tv.synth.truthTime(camsTrue(2), clock2) - tv.synth.truthTime(camsTrue(1), camsTrue(1).recordStart)));
R.readoutErrMs = 1000 * (sync.readout - [camsTrue.readout]);
R.seconds = toc(t0);
writeOut(R, S, outDir);
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
L{end+1} = sprintf('SYNTHETIC. %d shots in %d rallies (90-minute singles session, 4K cameras, 0.5 px detector noise). Truth flights: ode45, spin decay (5 s), C_L following the spin parameter with 15%% per-shot scatter, per-shot C_D (sd 0.024), wind gusts (about 1 m/s). The fitter assumes none of these. Run time %.0f min.', ...
    numel(rows), numel(S.pieces), R.seconds / 60);
L{end+1} = '';
L{end+1} = '| Measure | Shots | Median | 90th percentile | Target |';
L{end+1} = '|---|---|---|---|---|';
L{end+1} = sprintf('| Shots found (hit within 30 ms) | %d of %d | | | 95%% (AC-06) |', nnz(f), numel(rows));
L{end+1} = line('Hit time error, ms', abs([rows.hitDtMs]), '', 1);
L{end+1} = line('Speed at contact error, mph', abs([rows.speedErr]) * 2.23694, '2 mph for 90% (AC-07)', 2);
L{end+1} = line('Bounce position error, cm', [rows.bounceErr] * 100, 'median 5 cm (AC-08)', 1);
L{end+1} = line('Spin effect error, cm', abs([rows.spinErr]) * 100, '10 cm (AC-10)', 1);
L{end+1} = line('Net clearance error, cm', abs([rows.netErr]) * 100, '3-5 cm (spec estimate)', 1);
L{end+1} = line('rpm error, %', abs([rows.rpmErrPct]), '10% (AC-11)', 0);
L{end+1} = sprintf('| In / out / net calls right | %d of %d | | | all |', nnz(callOk), nnz(callable));
L{end+1} = line('Bounce error after a short flight (< 0.25 s to the next hit), cm', [rows(short).bounceErr] * 100, '', 1);
L{end+1} = line('Bounce error, all other shots, cm', [rows(~short).bounceErr] * 100, '', 1);
L{end+1} = '';
L{end+1} = sprintf('Session timing at mid-session: %.2f ms. Readout time error: camera 1 %.2f ms, camera 2 %.2f ms. Wind found %s m/s (mean truth %s, gusts not modelled by the fit). Session C_D %.3f.', ...
    R.syncErrMs, R.readoutErrMs(1), R.readoutErrMs(2), mat2str(round(R.air.wind(1:2) * 10) / 10), mat2str(S.air.wind(1:2)), median([S.shots.CD]));
fid = fopen(fullfile(outDir, 'fitstudy.md'), 'w', 'n', 'UTF-8');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
fid = fopen(fullfile(outDir, 'fitstudy_shots.csv'), 'w');
fprintf(fid, 'rally,index,kind,serve,truthCall,call,found,hitDtMs,speedErr_mps,bounceErr_m,spinErr_m,netErr_m,rpmErrPct,shortAfterBounce,toNextHit_s,bounceSegN,bounceSegS,rmsPx\n');
for r = rows'
    fprintf(fid, '%d,%d,%s,%d,%s,%s,%d,%.2f,%.3f,%.4f,%.4f,%.4f,%.1f,%d,%.3f,%g,%.3f,%.2f\n', r.rally, r.index, r.kind, r.serve, ...
        r.truthCall, r.call, r.found, r.hitDtMs, r.speedErr, r.bounceErr, r.spinErr, r.netErr, r.rpmErrPct, r.shortAfterBounce, ...
        r.toNextHit, r.bounceSegN, r.bounceSegS, r.rms);
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
