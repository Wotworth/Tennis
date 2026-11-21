function R = detectorSizeStudy(outDir, opts)
%DETECTORSIZESTUDY  How each ball detector finds and places a ball of each size (SYNTHETIC; TV-DET).
%   R = detectorSizeStudy('out/sizestudy')
%   Chris, 20 Nov: compare the detectors on speed over hundreds of shots (item 5), and report
%   recall against ball size, 2 to 6+ px, at the sizes a 4K Linear camera sees at the far corner
%   (item 25). Whole 4K frames are too slow to draw by the thousand, so each trial is a small
%   patch: a court-coloured background with texture and, in a third of the trials, a line; an
%   optic-yellow ball of diameter d with soft edges, smeared over the shutter time, moving at a
%   random speed and direction; sensor noise; and video coding stood in for by JPEG (quality
%   opts.jpegQ): the court coded once, the blocks round the ball coded again in every frame.
%   Detectors, run exactly as the two-camera pipeline runs them:
%     learned     moving spots (frames 1/30 s apart), first pass and classifier (round 5), the
%                 centre placed by tv.detect.ballCentre; "found" = a spot within max(2, d) px
%                 of the truth scoring over cfg.ballCut (0.05; what the tracker is given) and
%                 over 0.5
%     learnedRaw  the same without the new centre (before 19 Nov)
%     colour      the first, colour-based detector on consecutive frames
%   R.table rows: detector, d, share with a spot on the ball (before the classifier), found share
%   (over 0.05 and over 0.5), centre error median, rms,
%   90th percentile (px), mean error along the motion (px). Written to sizestudy.md and
%   sizestudy.csv; tv.synth.detectorModel turns the csv into the error model the fit study
%   uses.
%   opts.realism true (Chris, 22 Nov, item 12): the pictures of tv.synth.realPatch instead (the ball
%   on the strings and passing bodies, heads and racquets, shadows, HEVC at the camera's quantiser
%   opts.qp, noise growing with the light, rolling shutter), opts.trialsPerCond trials per
%   condition and size. The csv then has two rows per detector and size: <detector> for the frames
%   in flight (opts.flightMix: clear court, the ball's shadow, a player's shadow) and
%   <detector>@hit for the frames round a contact (opts.hitMix: strings, bodies, heads); the fit
%   study uses the second within tv.synth.observe's hitMs of a hit. RETUNE(real footage): the mixes.
if nargin < 1, outDir = fullfile(pwd, 'out', 'sizestudy'); end
if nargin < 2, opts = struct(); end
d0 = struct('sizes', [2 3 4 5 6 8], 'trials', 150, 'seed', 3, 'fps', 240, 'shutter', 1 / 1920, ...
    'speedPxPerFrame', [2 10], 'noise', 2, 'jpegQ', 85, 'patch', 160, 'realism', false, 'qp', 23, 'trialsPerCond', 60, ...
    'flightMix', struct('clear', 0.6, 'ballShadow', 0.2, 'playerShadow', 0.2), ...
    'hitMix', struct('strings', 0.4, 'bodyFront', 0.3, 'bodyBehind', 0.3));
fn = fieldnames(d0);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d0.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
if opts.realism, R = realStudy(outDir, opts); return; end
tv.util.seed(opts.seed);
cfg = tv.pipeline.defaults();
m = tv.detect.ballModel();  net = tv.detect.loadBallNet(m.net);  pre = tv.detect.loadBallNet(m.pre);
K = max(1, round(2 * opts.fps / 60));                 % frames 1/30 s apart, as tv.detect.learnedCandidates
P = opts.patch;
[X, Y] = meshgrid(1:P, 1:P);
names = {'learned', 'learnedRaw', 'colour'};
rows = {};
tmp = [tempname() '.jpg'];
for d = opts.sizes
    E = struct();  for n = names, E.(n{1}) = struct('proposed', 0, 'found05', 0, 'found5', 0, 'err', zeros(0, 1), 'along', zeros(0, 1)); end
    for trial = 1:opts.trials
        % the empty court: hard-court blue or clay, with a fine texture; sometimes a line
        base = [40 90 160];  if rand() < 0.3, base = [170 95 70]; end
        tex = imfilter(randn(P, P), fspecial('gaussian', 7, 1.5), 'replicate') * 12;
        bg = repmat(reshape(base, 1, 1, 3), P, P) + repmat(tex, 1, 1, 3);
        if rand() < 0.33
            a = rand() * pi;  off = (rand() - 0.5) * 40;  w = 3 + 4 * rand();
            dl = abs((X - P / 2) * sin(a) - (Y - P / 2) * cos(a) - off);
            ln = min(max(w / 2 + 0.5 - dl, 0), 1);
            bg = bg .* (1 - ln) + 235 * ln;
        end
        bg = double(jpegOnce(uint8(min(max(bg, 0), 255)), opts.jpegQ, tmp));   % the court as coded once
        % the ball's path: speed in px per frame, through the patch centre at frame 0
        sp = opts.speedPxPerFrame(1) + diff(opts.speedPxPerFrame) * rand();
        th = 2 * pi * rand();  vel = sp * [cos(th), sin(th)];
        c0 = P / 2 + rand(1, 2) - 0.5;
        ballRGB = [205 230 40] .* (0.85 + 0.3 * rand());
        frame = @(t) shoot(bg, X, Y, c0 + vel * t, vel, d, ballRGB, opts, tmp);
        cur = frame(0);
        % --- learned (both centres) ---
        prev = frame(-K);  nxt = frame(K);
        S = struct('mask', true(P, P), 'dmin', 0.8 * d * ones(P, P), 'dmax', 1.25 * d * ones(P, P) + 1);
        [C, ~, pa, na] = tv.detect.motionProposals(prev, cur, nxt, S, struct('align', false));
        if ~isempty(C)
            M = [0.8 * d * ones(size(C, 1), 1), 1.25 * d * ones(size(C, 1), 1) + 1];
            sc = tv.detect.ballScale(C(:, 5), M);
            p = tv.detect.ballScores(net, pre, tv.detect.ballCrops(pa, cur, na, C, 48, sc), M ./ sc);
            [dist, j] = min(hypot(C(:, 1) - c0(1), C(:, 2) - c0(2)));
            if dist <= max(2, d)
                E.learned.proposed = E.learned.proposed + 1;  E.learnedRaw.proposed = E.learnedRaw.proposed + 1;
                xyR = C(j, 1:2);  j0 = j;
                xyN = tv.detect.ballCentre(cur, bg, xyR, C(j, 3:5), M(j, 2));
                E.learned = tally(E.learned, p(j), xyN - c0, vel);
                E.learnedRaw = tally(E.learnedRaw, p(j), xyR - c0, vel);
            end
        end
        % --- colour: consecutive frames ---
        F = cat(4, frame(-1), cur, frame(1));
        Cc = tv.detect.ballCandidates(F, bg, true(P, P), struct('maxArea', max(30, pi / 4 * (2 * d)^2 * 3)));
        if ~isempty(Cc)
            [dist, j] = min(hypot(Cc(:, 2) - c0(1), Cc(:, 3) - c0(2)));
            if dist <= max(2, d), E.colour.proposed = E.colour.proposed + 1;  E.colour = tally(E.colour, 1, Cc(j, 2:3) - c0, vel); end
        end
    end
    for n = names
        e = E.(n{1});  T = opts.trials;
        r = e.err;  if isempty(r), r = NaN; end
        rows(end+1, :) = {n{1}, d, e.proposed / T, e.found05 / T, e.found5 / T, median(r), sqrt(mean(r .^ 2)), prc(r, 90), mean(e.along)}; %#ok<AGROW>
    end
    fprintf('d = %d px done\n', d);
end
if exist(tmp, 'file'), delete(tmp); end
R.table = rows;  R.opts = opts;
writeOut(R, outDir);
end

function R = realStudy(outDir, opts)
% the size study on tv.synth.realPatch pictures: every condition at every size, then the mixes
tv.util.seed(opts.seed);
m = tv.detect.ballModel();  net = tv.detect.loadBallNet(m.net);  pre = tv.detect.loadBallNet(m.pre);
K = max(1, round(2 * opts.fps / 60));
P = opts.patch;
conds = [fieldnames(opts.flightMix); fieldnames(opts.hitMix)]';
% learnedColour (22 Nov, item 12): the learned detector's spot, or the colour detector's where the
% learned one has none, the combination for the frames round a hit
names = {'learned', 'learnedRaw', 'colour', 'learnedColour'};
po = struct('patch', P, 'fps', opts.fps, 'shutter', opts.shutter, 'qp', opts.qp);
bpp = [];
for d = opts.sizes
    for c = conds
        E = struct();  for n = names, E.(n{1}) = struct('proposed', 0, 'found05', 0, 'found5', 0, 'err', zeros(0, 1), 'along', zeros(0, 1)); end
        for trial = 1:opts.trialsPerCond
            sp = opts.speedPxPerFrame(1) + diff(opts.speedPxPerFrame) * rand();
            th = 2 * pi * rand();  vel = sp * [cos(th), sin(th)];
            c0 = P / 2 + rand(1, 2) - 0.5;
            ballRGB = [205 230 40] .* (0.85 + 0.3 * rand());
            [F, bg, info] = tv.synth.realPatch(c{1}, d, c0, vel, ballRGB, [-K -1 0 1 K], po);
            bpp(end+1) = info.bpp; %#ok<AGROW>
            E = detectAll(E, F(:, :, :, 1), F(:, :, :, 2), F(:, :, :, 3), F(:, :, :, 4), F(:, :, :, 5), double(bg), d, c0, vel, P, net, pre);
        end
        T.(c{1}).(sprintf('d%d', d)) = E;
    end
    fprintf('d = %d px done\n', d);
end
rows = {};  byCond = {};
for n = names
    for d = opts.sizes
        key = sprintf('d%d', d);
        for c = conds
            e = T.(c{1}).(key).(n{1});  t = opts.trialsPerCond;
            byCond(end+1, :) = {n{1}, d, c{1}, e.proposed / t, e.found05 / t, e.found5 / t, prc([e.err; NaN], 50)}; %#ok<AGROW>
        end
        rows(end+1, :) = mixRow(n{1}, d, T, key, opts.flightMix, opts.trialsPerCond); %#ok<AGROW>
        rows(end+1, :) = mixRow([n{1} '@hit'], d, T, key, opts.hitMix, opts.trialsPerCond); %#ok<AGROW>
    end
end
R.table = rows;  R.byCond = byCond;  R.opts = opts;  R.bpp = median(bpp);
writeOut(R, outDir);
end

function row = mixRow(name, d, T, key, mix, t)
% the mix of conditions: shares weighted, error statistics from the pooled errors weighted alike
base = strtok(name, '@');
prop = 0;  f05 = 0;  f5 = 0;  err = [];  w = [];  along = 0;  wa = 0;
for c = fieldnames(mix)'
    e = T.(c{1}).(key).(base);  q = mix.(c{1});
    prop = prop + q * e.proposed / t;  f05 = f05 + q * e.found05 / t;  f5 = f5 + q * e.found5 / t;
    if ~isempty(e.err)
        err = [err; e.err]; %#ok<AGROW>
        w = [w; q * (e.found05 / t) / numel(e.err) * ones(numel(e.err), 1)]; %#ok<AGROW>
        along = along + q * sum(e.along) / numel(e.along);  wa = wa + q;
    end
end
if isempty(err), row = {name, d, prop, f05, f5, NaN, NaN, NaN, NaN}; return; end
w = w / sum(w);
row = {name, d, prop, f05, f5, wprc(err, w, 50), sqrt(sum(w .* err .^ 2)), wprc(err, w, 90), along / max(wa, eps)};
end

function v = wprc(x, w, p)
[x, i] = sort(x);  c = cumsum(w(i));
v = x(find(c >= p / 100 - 1e-12, 1));
end

function E = detectAll(E, prev, prev1, cur, nxt1, nxt, bg, d, c0, vel, P, net, pre)
% the detectors on one trial's frames, as in the main loop (learnedColour in the realistic study only)
S = struct('mask', true(P, P), 'dmin', 0.8 * d * ones(P, P), 'dmax', 1.25 * d * ones(P, P) + 1);
[C, ~, pa, na] = tv.detect.motionProposals(prev, cur, nxt, S, struct('align', false));
if ~isempty(C)
    M = [0.8 * d * ones(size(C, 1), 1), 1.25 * d * ones(size(C, 1), 1) + 1];
    sc = tv.detect.ballScale(C(:, 5), M);
    p = tv.detect.ballScores(net, pre, tv.detect.ballCrops(pa, cur, na, C, 48, sc), M ./ sc);
    [dist, j] = min(hypot(C(:, 1) - c0(1), C(:, 2) - c0(2)));
    if dist <= max(2, d)
        E.learned.proposed = E.learned.proposed + 1;  E.learnedRaw.proposed = E.learnedRaw.proposed + 1;
        xyR = C(j, 1:2);  j0 = j;
        xyN = tv.detect.ballCentre(cur, bg, xyR, C(j, 3:5), M(j, 2));
        E.learned = tally(E.learned, p(j), xyN - c0, vel);
        E.learnedRaw = tally(E.learnedRaw, p(j), xyR - c0, vel);
    end
end
F = cat(4, prev1, cur, nxt1);
Cc = tv.detect.ballCandidates(F, bg, true(P, P), struct('maxArea', max(30, pi / 4 * (2 * d)^2 * 3)));
okC = false;
if ~isempty(Cc)
    [dist, j] = min(hypot(Cc(:, 2) - c0(1), Cc(:, 3) - c0(2)));  okC = dist <= max(2, d);  jc = j;
    if okC, E.colour.proposed = E.colour.proposed + 1;  E.colour = tally(E.colour, 1, Cc(j, 2:3) - c0, vel); end
end
if isfield(E, 'learnedColour')
    % the learned spot when it scores over 0.05, else the colour detector's
    if exist('xyN', 'var') && p(j0) > 0.05
        E.learnedColour.proposed = E.learnedColour.proposed + 1;
        E.learnedColour = tally(E.learnedColour, p(j0), xyN - c0, vel);
    elseif okC
        E.learnedColour.proposed = E.learnedColour.proposed + 1;
        E.learnedColour = tally(E.learnedColour, 1, Cc(jc, 2:3) - c0, vel);
    end
end
end

function E = tally(E, score, e, vel)
if score > 0.05
    E.found05 = E.found05 + 1;
    E.err(end+1, 1) = norm(e);
    E.along(end+1, 1) = e * vel(:) / max(norm(vel), eps);
end
if score > 0.5, E.found5 = E.found5 + 1; end
end

function img = shoot(bg, X, Y, c, vel, d, rgb, opts, tmp)
% The ball smeared over the shutter (five instants) and sensor noise. Video coding: the still
% court is coded once and kept from frame to frame (as a video codec does), so only the 8-px
% blocks round the ball are coded again, here as a JPEG of those blocks.
P = size(bg, 1);
cover = zeros(P, P);
smear = vel * opts.shutter * opts.fps;               % px moved while the shutter is open
for s = linspace(-0.5, 0.5, 5)
    cc = c + s * smear;
    cover = cover + min(max(d / 2 + 0.5 - hypot(X - cc(1), Y - cc(2)), 0), 1) / 5;
end
img = bg .* (1 - cover) + reshape(rgb, 1, 1, 3) .* cover;
img = uint8(min(max(img + opts.noise * randn(size(img)), 0), 255));
[yy, xx] = find(cover > 0);
if isempty(yy), return; end
r0 = max(1, floor((min(yy) - 9) / 8) * 8 + 1);  r1 = min(P, ceil((max(yy) + 8) / 8) * 8);
c0 = max(1, floor((min(xx) - 9) / 8) * 8 + 1);  c1 = min(P, ceil((max(xx) + 8) / 8) * 8);
imwrite(img(r0:r1, c0:c1, :), tmp, 'Quality', opts.jpegQ);
img(r0:r1, c0:c1, :) = imread(tmp);
end

function img = jpegOnce(img, q, tmp)
imwrite(img, tmp, 'Quality', q);
img = imread(tmp);
end

function v = prc(x, p)
x = sort(x(isfinite(x)));
if isempty(x), v = NaN; return; end
v = x(max(1, ceil(p / 100 * numel(x))));
end

function writeOut(R, outDir)
L = {'# Ball detectors against ball size (SYNTHETIC patches)', ''};
if R.opts.realism
    L{end+1} = sprintf(['Realistic pictures (tv.synth.realPatch): %d trials per condition and size; frames %d a second, shutter 1/%d s, ' ...
        'ball moving %g to %g px a frame; noise growing with the light; rolling shutter; every trial''s frames coded with HEVC ' ...
        '(4:2:0) at quantiser %d (median %.3f bits per pixel per frame on these patches). Rows <detector>: the frames in flight (%s); ' ...
        '<detector>@hit: the frames round a contact (%s). "Found": a spot within max(2, d) px of the ball scoring over 0.05 or 0.5.'], ...
        R.opts.trialsPerCond, R.opts.fps, round(1 / R.opts.shutter), R.opts.speedPxPerFrame, R.opts.qp, R.bpp, mixText(R.opts.flightMix), mixText(R.opts.hitMix));
else
L{end+1} = sprintf(['%d trials per size; frames %d a second, shutter 1/%d s, ball moving %g to %g px a frame, ' ...
    'noise %g levels, the blocks round the ball coded as a JPEG at quality %d in each frame (the court coded once). "Found": a spot within max(2, d) px of the ball scoring over 0.05 ' ...
    '(what the tracker is given) or 0.5. Errors are over the spots found at 0.05.'], R.opts.trials, R.opts.fps, round(1 / R.opts.shutter), ...
    R.opts.speedPxPerFrame, R.opts.noise, R.opts.jpegQ);
end
L{end+1} = '';
L{end+1} = '| Detector | Ball (px) | A spot on it | Found (> 0.05) | Found (> 0.5) | Centre error median (px) | rms | 90th pct | Mean along the motion |';
L{end+1} = '|---|---|---|---|---|---|---|---|---|';
for i = 1:size(R.table, 1)
    r = R.table(i, :);
    L{end+1} = sprintf('| %s | %d | %.0f%% | %.0f%% | %.0f%% | %.2f | %.2f | %.2f | %+.2f |', r{1}, r{2}, 100 * r{3}, 100 * r{4}, 100 * r{5}, r{6}, r{7}, r{8}, r{9}); %#ok<AGROW>
end
if isfield(R, 'byCond')
    L{end+1} = '';  L{end+1} = '## Each condition alone';  L{end+1} = '';
    L{end+1} = '| Detector | Ball (px) | Condition | A spot on it | Found (> 0.05) | Found (> 0.5) | Centre error median (px) |';
    L{end+1} = '|---|---|---|---|---|---|---|';
    for i = 1:size(R.byCond, 1)
        r = R.byCond(i, :);
        L{end+1} = sprintf('| %s | %d | %s | %.0f%% | %.0f%% | %.0f%% | %.2f |', r{1}, r{2}, r{3}, 100 * r{4}, 100 * r{5}, 100 * r{6}, r{7}); %#ok<AGROW>
    end
end
fid = fopen(fullfile(outDir, 'sizestudy.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
fid = fopen(fullfile(outDir, 'sizestudy.csv'), 'w');
fprintf(fid, 'detector,d,proposed,found05,found5,errMedian,errRms,err90,along\n');
for i = 1:size(R.table, 1)
    r = R.table(i, :);
    fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', r{:});
end
fclose(fid);
end

function t = mixText(m)
f = fieldnames(m);  t = '';
for i = 1:numel(f), t = [t sprintf('%s%s %.0f%%', tv.testing.ternary(i > 1, ', ', ''), f{i}, 100 * m.(f{i}))]; end %#ok<AGROW>
end
