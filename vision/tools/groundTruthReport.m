function G = groundTruthReport(M, runs, outFile)
%GROUNDTRUTHREPORT  Accuracy against tape-measured truth from a real session (Chris, 20 Nov; Tuesday).
%   G = groundTruthReport(M, runs, 'groundtruth.md')
%   M: the measurements (vision/groundtruth/<date>.json, read with tv.readJson; template.json shows
%      the fields). runs: struct with the pipeline's results per clip, by the clip names M uses
%      (runs.clip2 = the result struct tv.pipeline.run returned for clip 2), plus, for the still
%      balls, runs.stillFrames = {frame from camera 1, frame from camera 2} at M.stillBalls.atS.
%   The first accuracy numbers not graded against our own labels or synthetic data:
%     cameras   the camera positions found from the court lines against the tape
%     drop      gravity and release height from the 3D points of each fall, with nothing assumed:
%               a free parabola z = a + b t + c t^2 through each fall's points (g = -2c, the top of
%               the parabola is the release height), against 9.81 m/s^2 and 2.00 m + the radius
%     still     each still ball found in both cameras' pictures and placed by the two sight lines,
%               against where it was put
%     targets   each bounce found near a taped cross, against the cross
%     machine   per machine setting: the spread of speed, spin effect and landing spot
%     spin      (optional, 22 Nov) the machine's spin from the striped balls the Hero 7 filmed
%               side-on (tools/spinFromStripe.m on M.spinTruth.file, or runs.stripe when already
%               run) against the system's rpm for the same feeds, in feed order, and whether each
%               truth falls inside the system's stated band (2 sd)
%   Parts whose clip is missing from runs are left out. G holds every number; the report is
%   written to outFile when given.
if nargin < 3, outFile = ''; end
G = struct();  L = {'# Ground truth: Tuesday''s session against the tape measure', ''};
if isfield(M, 'cameras') && isfield(runs, 'cams')
    G.cameras = cameraCheck(M.cameras, runs.cams);
    L{end+1} = '| Camera | Found from the lines (x, y, z) | Taped (x, y, z) | Distance, cm |';
    L{end+1} = '|---|---|---|---|';
    for c = G.cameras(:)'
        L{end+1} = sprintf('| %d | %s | %s | %.1f |', c.cam, mat2str(round(c.found * 100) / 100), mat2str(round(c.taped * 100) / 100), 100 * c.err); %#ok<AGROW>
    end
    L{end+1} = '';
end
if isfield(M, 'drops') && isfield(runs, M.drops.clip)
    G.drop = dropCheck(runs.(M.drops.clip), M.drops);
    L{end+1} = sprintf('Drops: %d falls. Gravity %.2f m/s^2 median (spread %.2f; truth 9.81). Release height %.3f m median (spread %.3f; truth %.3f to the ball''s centre).', ...
        numel(G.drop.g), median(G.drop.g), iqrOf(G.drop.g), median(G.drop.top), iqrOf(G.drop.top), M.drops.releaseHeightM);
    L{end+1} = '';
end
if isfield(M, 'stillBalls') && isfield(runs, 'stillFrames') && isfield(runs, 'cams')
    G.still = stillCheck(runs.stillFrames, runs.bg, runs.cams, M.stillBalls.balls);
    L{end+1} = '| Still ball | Found in both pictures | 3D error, cm | Gap between the sight lines, cm |';
    L{end+1} = '|---|---|---|---|';
    for b = G.still(:)'
        L{end+1} = sprintf('| %s | %d | %.1f | %.1f |', b.name, b.found, 100 * b.err, 100 * b.gap); %#ok<AGROW>
    end
    L{end+1} = '';
end
if isfield(M, 'targets') && isfield(runs, M.targets.clip)
    G.targets = targetCheck(runs.(M.targets.clip), M.targets.spots);
    L{end+1} = '| Target | Bounces found within 0.5 m | Bounce error median, cm | Worst, cm |';
    L{end+1} = '|---|---|---|---|';
    for t = G.targets(:)'
        L{end+1} = sprintf('| %s | %d | %.1f | %.1f |', t.name, t.n, 100 * t.median, 100 * t.worst); %#ok<AGROW>
    end
    L{end+1} = '';
end
if isfield(M, 'machine')
    ms = M.machine;  if iscell(ms), ms = [ms{:}]; end
    L{end+1} = '| Machine setting | Shots | Speed, mph (sd) | Spin effect, ft (sd) | Landing spread, cm sd |';
    L{end+1} = '|---|---|---|---|---|';
    G.machine = struct('setting', {}, 'n', {}, 'speed', {}, 'speedSd', {}, 'spin', {}, 'spinSd', {}, 'landSd', {});
    for m = ms(:)'
        if ~isfield(runs, m.clip), continue; end
        r = machineCheck(runs.(m.clip), m.setting);
        G.machine(end+1) = r;
        L{end+1} = sprintf('| %s | %d | %.1f (%.1f) | %.1f (%.1f) | %.0f |', r.setting, r.n, r.speed, r.speedSd, r.spin, r.spinSd, r.landSd); %#ok<AGROW>
    end
end
if isfield(M, 'spinTruth') && isfield(runs, M.spinTruth.clip)
    st = [];
    if isfield(runs, 'stripe'), st = runs.stripe;
    elseif isfield(M.spinTruth, 'file') && exist(M.spinTruth.file, 'file')
        so = struct('spin', '');  if isfield(M.spinTruth, 'spin'), so.spin = M.spinTruth.spin; end
        st = spinFromStripe(M.spinTruth.file, so);
    end
    if ~isempty(st)
        G.spin = spinCheck(st, runs.(M.spinTruth.clip));
        L{end+1} = '| Striped ball | rpm from the stripe | rpm from the system (2 sd) | Difference | Truth inside the band |';
        L{end+1} = '|---|---|---|---|---|';
        for b = G.spin.rows(:)'
            L{end+1} = sprintf('| %d | %.0f +/- %.0f | %.0f (%.0f) | %+.0f | %s |', b.ball, b.stripe, b.stripeSd, b.system, 2 * b.systemSd, b.system - b.stripe, tv.testing.ternary(b.inside, 'yes', 'no')); %#ok<AGROW>
        end
        L{end+1} = sprintf('Spin: %d balls on the stripe, %d feeds from the system; matched in order. Median difference %.0f rpm (%.0f%%); truth inside the stated band for %d of %d.', ...
            G.spin.nStripe, G.spin.nFeeds, G.spin.medianDiff, 100 * G.spin.medianFrac, nnz([G.spin.rows.inside]), numel(G.spin.rows));
        L{end+1} = '';
    end
end
G.text = strjoin(L, newline);
if ~isempty(outFile)
    fid = fopen(outFile, 'w');  fprintf(fid, '%s\n', G.text);  fclose(fid);
    % the numbers alone, for the app's accuracy page (Chris, 22 Nov, item 14): <outFile>.json
    [dd, bb] = fileparts(outFile);
    tv.util.writeJson(fullfile(dd, [bb '.json']), forApp(G, M));
end
end

function A = forApp(G, M)
% groundTruthReport's results in the app's format (app: vision/Accuracy.kt). Distances in cm.
A = struct('session', '', 'synthetic', false, 'cameras', {{}}, 'drop', [], 'still', {{}}, 'targets', {{}}, 'machine', {{}}, 'spin', []);
if isfield(M, 'session'), A.session = M.session; end
if isfield(M, 'synthetic'), A.synthetic = logical(M.synthetic); end
if isfield(G, 'cameras')
    A.cameras = arrayfun(@(c) struct('cam', c.cam, 'found', c.found(:)', 'taped', c.taped(:)', 'errCm', 100 * c.err), G.cameras(:)', 'UniformOutput', false);
end
if isfield(G, 'drop') && ~isempty(G.drop.g)
    A.drop = struct('n', numel(G.drop.g), 'g', median(G.drop.g), 'gSpread', iqrOf(G.drop.g), 'gTruth', 9.81, ...
        'heightM', median(G.drop.top), 'heightSpreadM', iqrOf(G.drop.top), 'heightTruthM', M.drops.releaseHeightM);
end
if isfield(G, 'still')
    A.still = arrayfun(@(b) struct('name', b.name, 'found', logical(b.found), 'errCm', 100 * b.err, 'gapCm', 100 * b.gap), G.still(:)', 'UniformOutput', false);
end
if isfield(G, 'targets')
    A.targets = arrayfun(@(t) struct('name', t.name, 'n', t.n, 'medianCm', 100 * t.median, 'worstCm', 100 * t.worst), G.targets(:)', 'UniformOutput', false);
end
if isfield(G, 'machine')
    A.machine = arrayfun(@(m) struct('setting', m.setting, 'n', m.n, 'speedMph', m.speed, 'speedSdMph', m.speedSd, ...
        'spinFt', m.spin, 'spinSdFt', m.spinSd, 'landSdCm', m.landSd), G.machine(:)', 'UniformOutput', false);
end
if isfield(G, 'spin')
    A.spin = struct('medianDiffRpm', G.spin.medianDiff, 'rows', {arrayfun(@(r) struct('ball', r.ball, 'stripeRpm', r.stripe, 'stripeSdRpm', r.stripeSd, ...
        'systemRpm', r.system, 'systemSdRpm', r.systemSd, 'inside', logical(r.inside)), G.spin.rows(:)', 'UniformOutput', false)});
end
end

function C = cameraCheck(Mc, cams)
c = tv.court.constants();
if iscell(Mc), Mc = [Mc{:}]; end
C = struct('cam', {}, 'found', {}, 'taped', {}, 'err', {});
for m = Mc(:)'
    sx = -1;  if strcmp(m.atEnd, 'far'), sx = 1; end
    taped = [sx * (c.halfLength + m.beyondBaselineM), -(c.halfDoubles + m.fromDoublesSidelineM), m.heightM];
    cam = cams(m.cam);  tw = tv.calib.rotate180(cam);
    p = cam.pos;  if norm(tw.pos - taped) < norm(p - taped), p = tw.pos; end   % either half-turn twin
    C(end+1) = struct('cam', m.cam, 'found', p, 'taped', taped, 'err', norm(p - taped)); %#ok<AGROW>
end
end

function D = dropCheck(res, drops)
% the falls: the 3D points the two cameras agree on (kept points, where the sight lines cross; no
% physics assumed), split where the ball goes up again (a bounce) or where the points stop a while.
% 22 Nov (dress rehearsal): this read the gate's log, which holds only rejected points, so a kept
% drop was never seen; it now reads the kept points (result.gatePoints)
X = zeros(0, 4);
if isfield(res, 'gatePoints')
    for r = 1:numel(res.gatePoints), X = [X; res.gatePoints{r}]; end %#ok<AGROW>
end
X = sortrows(X);
[~, iu] = unique(round(X(:, 1) * 1e4));  X = X(iu, :);
D = struct('g', [], 'top', [], 'n', []);
if size(X, 1) < 8, return; end
cut = [0; find(diff(X(:, 1)) > 0.05 | diff(X(:, 4)) > 0.02); size(X, 1)];  % a gap, or the ball going up
for i = 1:numel(cut) - 1
    s = X(cut(i) + 1:cut(i + 1), :);
    if size(s, 1) < 8 || s(1, 4) < 1.0, continue; end                      % only falls from high up
    t = s(:, 1) - s(1, 1);
    p = polyfit(t, s(:, 4), 2);
    if p(1) >= 0, continue; end
    D.g(end+1) = -2 * p(1);
    D.top(end+1) = p(3) - p(2) ^ 2 / (4 * p(1));
    D.n(end+1) = size(s, 1);
end
end

function B = stillCheck(frames, bg, cams, balls)
if iscell(balls), balls = [balls{:}]; end
B = struct('name', {}, 'found', {}, 'err', {}, 'gap', {});
for b = balls(:)'
    P = [b.x b.y b.z];
    rays = zeros(2, 3);  ok = true;
    for k = 1:2
        [px, okp] = tv.camera.project(cams(k), P);
        if ~okp, ok = false; break; end
        uv = findBall(frames{k}, bg{k}, px);
        if isempty(uv), ok = false; break; end
        rays(k, :) = tv.camera.rays(cams(k), uv);
    end
    if ~ok, B(end+1) = struct('name', b.name, 'found', false, 'err', NaN, 'gap', NaN); continue; end %#ok<AGROW>
    [Xh, gap] = closest(cams(1).pos, rays(1, :), cams(2).pos, rays(2, :));
    B(end+1) = struct('name', b.name, 'found', true, 'err', norm(Xh - P), 'gap', gap); %#ok<AGROW>
end
end

function uv = findBall(img, bg, px)
% the middle of the biggest patch that differs from the empty court within 30 px of where the ball should be
r = 30;  [h, w, ~] = size(img);
xs = max(1, round(px(1)) - r):min(w, round(px(1)) + r);  ys = max(1, round(px(2)) - r):min(h, round(px(2)) + r);
D = sum(abs(double(img(ys, xs, :)) - double(bg(ys, xs, :))), 3);
th = max(40, median(D(:)) + 6 * 1.4826 * median(abs(D(:) - median(D(:)))));
L = bwlabel(D > th, 8);
uv = [];
if max(L(:)) == 0, return; end
a = accumarray(L(L > 0), 1);
[~, k] = max(a);
[yy, xx] = find(L == k);
wt = D(L == k);
uv = [sum(xx .* wt) / sum(wt) + xs(1) - 1, sum(yy .* wt) / sum(wt) + ys(1) - 1];
end

function [X, gap] = closest(p1, d1, p2, d2)
% the midpoint of the shortest segment between two sight lines, and its length
w = p1 - p2;  a = d1 * d1';  b = d1 * d2';  c = d2 * d2';  d = d1 * w';  e = d2 * w';
den = a * c - b ^ 2;
s = (b * e - c * d) / den;  t = (a * e - b * d) / den;
q1 = p1 + s * d1;  q2 = p2 + t * d2;
X = (q1 + q2) / 2;  gap = norm(q1 - q2);
end

function T = targetCheck(res, spots)
if iscell(spots), spots = [spots{:}]; end
bounces = zeros(0, 2);
for r = 1:numel(res.events)
    e = res.events{r};
    if isempty(e), continue; end
    e = e(strcmp({e.type}, 'bounce'));
    for i = 1:numel(e), bounces(end+1, :) = e(i).p(1:2); end %#ok<AGROW>
end
T = struct('name', {}, 'n', {}, 'median', {}, 'worst', {});
for s = spots(:)'
    d = hypot(bounces(:, 1) - s.x, bounces(:, 2) - s.y);
    d = d(d < 0.5);
    if isempty(d), T(end+1) = struct('name', s.name, 'n', 0, 'median', NaN, 'worst', NaN); continue; end %#ok<AGROW>
    T(end+1) = struct('name', s.name, 'n', numel(d), 'median', median(d), 'worst', max(d)); %#ok<AGROW>
end
end

function r = machineCheck(res, setting)
sh = res.shots;
if isempty(sh), r = struct('setting', setting, 'n', 0, 'speed', NaN, 'speedSd', NaN, 'spin', NaN, 'spinSd', NaN, 'landSd', NaN); return; end
if iscell(sh), sh = [sh{:}]; end
feed = sh(arrayfun(@(s) s.index == 1, sh));            % the machine's own ball: the first shot of each "rally"
sp = [feed.speedContact] * 2.23694;
se = arrayfun(@(s) nanIfEmpty(s.spinEffect), feed) * 3.28084;
b = cell2mat(arrayfun(@(s) bounceOf(s), feed(:), 'UniformOutput', false));
landSd = NaN;  if size(b, 1) > 1, landSd = 100 * sqrt(sum(var(b, 0, 1))); end
r = struct('setting', setting, 'n', numel(feed), 'speed', mean(sp), 'speedSd', std(sp), ...
    'spin', mean(se(isfinite(se))), 'spinSd', std(se(isfinite(se))), 'landSd', landSd);
end

function S = spinCheck(st, res)
% the stripe's balls against the machine's feeds, both in the order they left the machine
sh = res.shots;  if iscell(sh), sh = [sh{:}]; end
feed = sh(arrayfun(@(s) s.index == 1, sh));
S.nStripe = numel(st.balls);  S.nFeeds = numel(feed);
n = min(S.nStripe, S.nFeeds);
S.rows = struct('ball', {}, 'stripe', {}, 'stripeSd', {}, 'system', {}, 'systemSd', {}, 'inside', {});
for i = 1:n
    sys = nanIfEmpty(feed(i).rpm);  sd = NaN;  if isfield(feed(i), 'rpmSd'), sd = nanIfEmpty(feed(i).rpmSd); end
    S.rows(end+1) = struct('ball', i, 'stripe', st.balls(i).rpm, 'stripeSd', st.balls(i).rpmSd, 'system', sys, 'systemSd', sd, ...
        'inside', abs(sys - st.balls(i).rpm) <= 2 * hypot(sd, st.balls(i).rpmSd)); %#ok<AGROW>
end
d = abs([S.rows.system] - [S.rows.stripe]);
S.medianDiff = median([d NaN(1, isempty(d))]);  S.medianFrac = median([d ./ [S.rows.stripe], NaN(1, isempty(d))]);
end

function v = nanIfEmpty(x)
if isempty(x), v = NaN; else, v = x; end
end

function b = bounceOf(s)
b = zeros(0, 2);
if isfield(s, 'bounce') && numel(s.bounce) >= 2 && all(isfinite(s.bounce(1:2))), b = s.bounce(1:2); end
end

function v = iqrOf(x)
x = sort(x(:));
if numel(x) < 2, v = NaN; return; end
v = x(max(1, ceil(0.75 * numel(x)))) - x(max(1, ceil(0.25 * numel(x))));
end
