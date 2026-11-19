function R = blockStudy(outDir, opts)
%BLOCKSTUDY  How much the flight fit loses when one camera is blocked (Chris, 18 Nov; TV-REC-01).
%   The same synthetic session as tools/fitStudy.m, shorter (tv.synth.studySession: truth the
%   fitter does not share; tv.synth.observe: 4K cameras, 0.5 px noise, misses, clock and pose
%   errors). It is reconstructed once with both cameras throughout, then again with one
%   camera blind, for half the shots, during: half of the flight to the bounce; that whole
%   flight; the bounce to the next hit; or all of it. The noise is
%   the same in every run, so each blocked shot is compared with itself unblocked. The
%   whole-flight cases are also run without the one-camera step (segments' opts.oneCam).
%   Writes blockstudy.md. opts: seed, minutes, targetShots, share.
if nargin < 1, outDir = fullfile(pwd, 'out', 'blockstudy'); end
if nargin < 2, opts = struct(); end
d = struct('seed', 11, 'minutes', 10, 'targetShots', 45, 'share', 0.5);     % 7 runs; the blocked ones are slow (the first try, 80 shots, ran out of CI time)
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
t0 = tic;
sc = tv.synth.defaultScenario();  sc.frameSize = [3840 2160];
camsTrue = tv.synth.cameras(sc);
S = tv.synth.studySession(opts.seed, struct('minutes', opts.minutes, 'targetShots', opts.targetShots));
cfg = tv.pipeline.defaults();
cases = {'both cameras throughout', '', 0, true
         'half of the flight to the bounce', 'part', 0.5, true
         'the whole flight to the bounce', 'beforeBounce', 1, true
         'the bounce to the next hit', 'afterBounce', 1, true
         'the hit to the next hit', 'whole', 1, true
         'the whole flight to the bounce, without the one-camera step', 'beforeBounce', 1, false
         'the bounce to the next hit, without the one-camera step', 'afterBounce', 1, false};
R = struct('name', cases(:, 1), 'rows', [], 'blocked', [], 'oneCam', 0);
for q = 1:size(cases, 1)
    setSeed(opts.seed + 1);                                   % the same noise, misses and pose errors every time
    oo = struct();
    if ~isempty(cases{q, 2}), oo = struct('blockShare', opts.share, 'blockWhere', cases{q, 2}, 'blockFrac', cases{q, 3}); end
    O = tv.synth.observe(S, camsTrue, oo);
    air = tv.physics.defaultParams();  air.rho = S.air.rho;
    air.wind = [0.5 * (2 * S.air.wind(1:2) + [0.8 -0.5]), 0];     % the forecast wind, not the truth (as fitStudy)
    rec = O.rec;  cams = O.cams;
    sync = tv.sync.clockLine(O.tracks, cams, rec, O.sync0);
    nR = size(O.tracks, 1);  segs = cell(nR, 1);  tracks = O.tracks;  prior = cfg.CDprior;  so = struct('oneCam', cases{q, 4});
    parfor r = 1:nR
        segs{r} = tv.recon.segments(tv.recon.pieces(tracks(r, :), rec, sync), cams, rec, sync, air, prior, so);
    end
    ro = struct('rounds', 2, 'windPrior', air.wind(1:2), 'indoor', false, 'readoutPrior', cfg.readoutPrior);
    [~, air, segs] = tv.recon.refineSession(segs, cams, rec, sync, air, cfg.CDprior, ro);
    ev = cell(nR, 1);
    for r = 1:nR, if ~isempty(segs{r}), ev{r} = tv.events.classify(segs{r}, air); end, end
    R(q).rows = tv.synth.scoreShots(S, segs, ev, air, cams);
    R(q).blocked = O.blocks(:, 1);
    all = vertcat(segs{:});  if ~isempty(all), R(q).oneCam = nnz([all.oneCam]); end
    fprintf('%s: %d shots blocked, %d one-camera flights, %.0f s so far\n', cases{q, 1}, numel(R(q).blocked), R(q).oneCam, toc(t0));
    if q > 1      % each row as soon as it exists (a run that is cut short still reports what it finished)
        b = R(q).blocked;  x = R(q).rows(b);  y = R(1).rows(b);
        fprintf('ROW | %s | %d | %d | %d | %s | %s | %s | %s | %d |\n', R(q).name, numel(b), nnz([y.found]), nnz([x.found]), ...
            two([y.bounceErr] * 100), two([x.bounceErr] * 100), two(abs([y.speedErr]) * 2.23694), two(abs([x.speedErr]) * 2.23694), R(q).oneCam);
    else
        fprintf('ROW all %d shots, both cameras: %d found, bounce %s cm, speed %s mph\n', numel(R(1).rows), nnz([R(1).rows.found]), two([R(1).rows.bounceErr] * 100), two(abs([R(1).rows.speedErr]) * 2.23694));
    end
end
% every blocked shot against itself with both cameras
base = R(1).rows;
L = {};
L{end+1} = '# Block study: the flight fit with one camera blind';
L{end+1} = '';
L{end+1} = sprintf('SYNTHETIC. %d shots in %d rallies (4K cameras, 0.5 px detector noise, misses, clock and pose errors; truth the fitter does not share). In each row one camera, picked at random, is blind for the stretch named, for about half the shots. "Before" is the same shots with both cameras throughout. Run time %.0f min.', ...
    numel(base), numel(S.pieces), toc(t0) / 60);
L{end+1} = '';
L{end+1} = '| One camera blind for | Shots | Found before | Found | Bounce error before, cm (median / 90th) | Bounce error, cm | Speed error before, mph | Speed error, mph | One-camera flights |';
L{end+1} = '|---|---|---|---|---|---|---|---|---|';
for q = 2:numel(R)
    b = R(q).blocked;  x = R(q).rows(b);  y = base(b);
    L{end+1} = sprintf('| %s | %d | %d | %d | %s | %s | %s | %s | %d |', R(q).name, numel(b), nnz([y.found]), nnz([x.found]), ...
        two([y.bounceErr] * 100), two([x.bounceErr] * 100), two(abs([y.speedErr]) * 2.23694), two(abs([x.speedErr]) * 2.23694), R(q).oneCam); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = sprintf('All %d shots with both cameras throughout: %d found, bounce %s cm, speed %s mph.', numel(base), nnz([base.found]), ...
    two([base.bounceErr] * 100), two(abs([base.speedErr]) * 2.23694));
txt = strjoin(L, newline);
fid = fopen(fullfile(outDir, 'blockstudy.md'), 'w');  fprintf(fid, '%s\n', txt);  fclose(fid);
fprintf('%s\n', txt);
end

function s = two(v)
v = v(isfinite(v));
if isempty(v), s = 'none'; return; end
v = sort(v);
s = sprintf('%.1f / %.1f (%d)', median(v), v(max(1, ceil(0.9 * numel(v)))), numel(v));
end

function setSeed(n)
if exist('OCTAVE_VERSION', 'builtin'), rand('state', n); randn('state', n); else, rng(n); end %#ok<RAND>
end
