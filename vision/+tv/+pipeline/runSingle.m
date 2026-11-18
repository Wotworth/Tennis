function R = runSingle(file, outDir, cfg)
%RUNSINGLE  One camera, one edited video: the earliest real-footage test (Chris, 17 Nov).
%   For footage from a single camera (a phone, the HERO7 trial, one MISSION 1 PRO alone): no
%   3D flights, speeds or spin, which need two cameras. Stages (each saved and skipped when
%   unchanged, tv.pipeline.stage):
%     probe     frame times (TV-ING-10)
%     clips     the clips of an edited "included rallies" export (tv.media.cuts); a whole
%               recording (wholeFile) is cut into windows of windowS seconds for processing
%     points    raw footage only: where the ball is in play, from the tracks (pointGapS joins
%               tracks closer than that, pointMinS drops shorter spans)
%     calib     the empty court (background), its lines, and the camera's pose and, for an
%               uncalibrated lens, focal length, from the court's line pattern alone
%               (tv.calib.courtFromLines); court corners out of view (TV-CAL-20)
%     detect    ball candidates and 2D tracks in every clip (TV-DET, TV-TRK); each frame is
%               first lined up with the empty court when the camera moved (steady,
%               tv.calib.steady, TV-CAL-14), as are the frames the hit and player checks use
%     follow    each track looks again where it predicts the ball, with looser limits in a
%               small window, and tracks that meet are joined (tv.track.follow, Chris 17 Nov;
%               follow, followOpts)
%     outlines  people every playerTrackStepS (1/6 s): large upright shapes against the clip's own
%               empty court (personMinArea px); tracks that never leave
%               a player are racquets or shirts and are dropped (tv.track.dropAtPlayer, Chris
%               17 Nov; dropPlayerTracks, playerTrackShare)
%     bounces   where a 2D track turns from falling to rising away from any player: a bounce,
%               placed on the ground through the camera; in or out of the singles court.
%               A turn inside a person's outline (widened by hitReach for the racquet) above
%               knee height is a hit, and one against the net hit the net: both skipped
%               (bounceSkipHits; people as in the outlines stage). One bounce seen twice within bounceMergeS
%               counts once
%     players   people every 1/cfg.single.playerHz s, placed on the court (TV-PLY-01)
%   cfg.single: overlayBoxes ([x0 y0 x1 y1] per row, pixels): burned-in graphics to blank
%   (e.g. SwingVision's mini-map, shot box and logo); lens (an uncalibrated rectilinear lens,
%   its focal length fitted); lineOpts; playerHz; clipOpts; stillMps (1.5: tracks slower than
%   this at the far end of the court are balls lying still, tv.track.dropStill), measured
%   over stillWindowS (0.25 s).
%   R: the stages' results, also saved as outDir/single.mat.
%   RETUNE(real footage): every cfg.single value; the detector's thresholds (tv.detect).
if nargin < 3 || isempty(cfg), cfg = tv.pipeline.defaults(); end
if ~isfield(cfg, 'single'), cfg.single = struct(); end
s = cfg.single;
d = struct('overlayBoxes', zeros(0, 4), 'lineOpts', struct('minContrast', 20, 'minLength', 40, 'reach', [3 7]), ...
           'playerHz', 2, 'clipOpts', struct(), 'hfovStart', 65, 'wholeFile', false, 'bounceMinPx', 1.5, ...
           'detectOpts', struct(), 'clipList', [], 'detectOnly', false, 'stillMps', 1.5, 'stillWindowS', 0.25, ...
           'bounceSkipHits', true, 'personMinArea', 1500, 'hitReach', 0.6, 'bounceMergeS', 0.3, ...
           'detector', 'classical', 'ballNetFile', '', 'precomputed', '', 'chainOpts', struct(), ...
           'bounceKindOpts', struct(), 'pointNeedsPlay', true, 'pointSplitS', 0.5, 'offBounceS', 0.75, 'pointTrackMinS', 0.5, ...
           'steady', true, 'steadyMaxPx', 40, 'windowS', 30, 'maxWindows', 0, 'maxJerkPx', 0, 'pointGapS', 4, 'pointMinS', 1.5, 'dropPlayerTracks', true, 'playerTrackStepS', 1 / 6, ...
           'playerTrackShare', 1, 'follow', true, 'followOpts', struct());
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(s, fn{k}), s.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
dd = dir(file);
key0 = sprintf('%s|%d|%s', file, dd.bytes, dd.date);
k = @(varargin) [key0 '|' jsonencode(varargin)];

P = tv.pipeline.stage(outDir, 'probe', k(), @() tv.media.probe(file));
rec = P;
C = tv.pipeline.stage(outDir, 'clips', k(s.clipOpts, s.wholeFile, s.windowS, s.maxWindows), @() findClips(rec, s));
K = tv.pipeline.stage(outDir, 'calib', k(s.overlayBoxes, s.lineOpts, s.hfovStart, s.steady, s.steadyMaxPx), @() calibrate(rec, s));
if ~isempty(K.corners.text) && isfield(cfg, 'notify'), cfg.notify('Camera framing', K.corners.text); end
if s.detectOnly
    % a worker: detect the clips in s.clipList only (each saved as it finishes), then stop
    detectAll(rec, C.clips, K, cfg, s, outDir);  R = [];  return
end
s.clipList = [];
learned = strcmp(s.detector, 'learned');
if learned
    % TV-DET-04 (brought forward, 18 Nov): colour-free motion proposals, the learned classifier,
    % and the ball's path as the best chain of scored detections. None of the rule stages below
    % (still balls, racquets, steered search, jumps, frame edge) are needed: each was a patch on
    % the colour detector's mistakes
    D = tv.pipeline.stage(outDir, 'detect', k(C.clips, s.overlayBoxes, cfg.court, K.cam.pos, 'learned', s.ballNetFile, s.precomputed, s.chainOpts), ...
        @() detectLearned(rec, C.clips, K, cfg, s, outDir));
    s.dropPlayerTracks = false;  s.follow = false;  s.maxJerkPx = 0;
    nStill = 0;
else
    D = tv.pipeline.stage(outDir, 'detect', k(C.clips, s.overlayBoxes, cfg.court, K.cam.pos, s.detectOpts, s.steady, s.steadyMaxPx), @() detectAll(rec, C.clips, K, cfg, s, outDir));
    [D, nStill] = dropStillTracks(D, rec, K, cfg, s);
end
nAtPlayer = 0;  PO = struct('frames', zeros(0, 1), 'raw', {{}});
if s.dropPlayerTracks || s.bounceSkipHits
    PO = tv.pipeline.stage(outDir, 'outlines', k(C.clips, K.cam.pos, s.steady, s.steadyMaxPx, s.personMinArea, s.playerTrackStepS, 'clipbg'), ...
        @() playerOutlines(rec, C.clips, K, s));
end
if s.dropPlayerTracks
    PO.boxes = cellfun(@(b) widen(b, s, 1), PO.raw, 'UniformOutput', false);
    for r = 1:numel(D.tracks)
        [D.tracks{r}, g] = tv.track.dropAtPlayer(D.tracks{r}, PO, s.playerTrackShare);
        nAtPlayer = nAtPlayer + nnz(g);
    end
end
% only tracks that passed both rules are followed (followed first, they grew along net tapes
% and fences on video 1), then checked for stillness again
nFollowed = 0;
if s.follow
    [D, nFollowed] = followAll(rec, C.clips, K, cfg, s, outDir, D);
    [D, n2] = dropStillTracks(D, rec, K, cfg, s);  nStill = nStill + n2;
end
% a ball doesn't jump: tracks with a step beyond s.maxJerkPx px per frame and six times their usual
% step are chains of unrelated spots (the steered search on clay, 17 Nov). Off (0) by default: on
% clay it also dropped 3 of 4 real ball tracks, which carry the same hops at their ends; the
% steered search's window cap (tv.track.follow maxRadius) is the fix
nRagged = 0;
for r = 1:numel(D.tracks) * (s.maxJerkPx > 0)
    t = D.tracks{r};
    if isempty(t), continue; end
    bad = arrayfun(@(q) raggedTrack(q, s.maxJerkPx), t);
    D.tracks{r} = t(~bad);  nRagged = nRagged + nnz(bad);
end
% steadying fills the strip a shift uncovers with the frame's border, and that strip moves: tracks
% that stay within s.steadyMaxPx of the frame's edge are dropped (Chris's clay video, 17 Nov)
nEdge = 0;
if s.steady && ~learned
    for r = 1:numel(D.tracks)
        t = D.tracks{r};
        if isempty(t), continue; end
        e = arrayfun(@(q) median(min([q.uv(:, 1) - 1, rec.width - q.uv(:, 1), q.uv(:, 2) - 1, rec.height - q.uv(:, 2)], [], 2)) < s.steadyMaxPx, t);
        D.tracks{r} = t(~e);  nEdge = nEdge + nnz(e);
    end
end
B = tv.pipeline.stage(outDir, 'bounces', k(s.bounceMinPx, K.cam.pos, s.stillMps, s.stillWindowS, s.bounceSkipHits, s.personMinArea, s.hitReach, s.bounceMergeS, 'clipbg', 'ownpts', 'dbl', 'edge', s.detector, s.maxJerkPx, s.steady, s.follow, s.followOpts, s.dropPlayerTracks, s.playerTrackStepS, s.playerTrackShare, 3, 'kind3', s.bounceKindOpts, cfg.court), @() findBounces(rec, D, K, s, PO, tv.court.interest(cfg.court)));
% the next court's ball (TV-ADJ-04, one camera): a ball in flight can't be placed, but a bounce is
% on the ground, so a track whose bounces are mostly outside the court of interest is the next
% court's ball and is dropped (its bounces stay in B, marked 'off')
nOff = 0;
if isfield(B.bounces, 'kind')
    for r = 1:numel(D.tracks)
        drop = false(numel(D.tracks{r}), 1);
        for ti = 1:numel(D.tracks{r})
            bb = B.bounces([B.bounces.clip] == r & [B.bounces.track] == ti);
            off = strcmp({bb.kind}, 'off');
            if ~any(off), continue; end
            if nnz(off) > nnz(~off & ~strcmp({bb.kind}, 'air')), drop(ti) = true; continue; end
            % a chain that ran from Chris's ball onto the next court's: the flights either side
            % of each bounce there (s.offBounceS seconds) are the next court's
            t = D.tracks{r}(ti);  f = double(t.frames(:));
            keep = true(size(f));
            for fo = double([bb(off).frame]), keep = keep & abs(f - fo) > s.offBounceS * rec.fps; end
            t.frames = t.frames(keep);  t.uv = t.uv(keep, :);
            if isfield(t, 'area'), t.area = t.area(keep); end
            if isfield(t, 'score'), t.score = t.score(keep); end
            D.tracks{r}(ti) = t;  drop(ti) = nnz(keep) < 2;
        end
        D.tracks{r} = D.tracks{r}(~drop);  nOff = nOff + nnz(drop);
    end
end
PT = struct('points', zeros(0, 2));
if s.wholeFile
    PT = tv.pipeline.stage(outDir, 'points', k(B.bounces, s.pointGapS, s.pointMinS, numel(D.tracks), cellfun(@numel, D.tracks), s.pointNeedsPlay, s.pointSplitS, s.pointTrackMinS, s.offBounceS, cellfun(@(t) sum(arrayfun(@(q) numel(q.frames), t)), D.tracks)), @() findPoints(rec, D, s, B.bounces));
end
Y = tv.pipeline.stage(outDir, 'players', k(s.playerHz, C.clips, K.cam.pos, s.steady), @() trackPlayers(rec, C.clips, K, s));
R = struct('rec', rec, 'clips', C.clips, 'cutT', C.cutT, 'cam', K.cam, 'calib', K.report, 'corners', K.corners, ...
    'bg', K.bg, 'overlayBoxes', s.overlayBoxes, 'candidates', {D.candidates}, 'tracks', {D.tracks}, ...
    'bounces', B.bounces, 'bounceSkips', struct('hits', B.hitsSkipped, 'net', B.netSkipped, 'duplicates', B.duplicates), 'players', Y.samples, 'stillTracks', nStill, 'stillMps', s.stillMps, 'playerTracks', nAtPlayer, 'followedPoints', nFollowed, 'points', PT.points, 'edgeTracks', nEdge, 'raggedTracks', nRagged, 'nextCourtTracks', nOff);
save(fullfile(outDir, 'single.mat'), '-struct', 'R');
end

function [D, n] = dropStillTracks(D, rec, K, cfg, s)
% tracks slower than s.stillMps at the farthest ground point of interest: balls lying still
box = tv.court.interest(cfg.court);
[gx, gy] = ndgrid(box.x, box.y);
dmax = max(sqrt(sum(([gx(:), gy(:), zeros(numel(gx), 1)] - K.cam.pos).^2, 2)));
minPx = s.stillMps / dmax * tv.lens.pxPerRad(K.cam.lens) / rec.fps;
n = 0;
for r = 1:numel(D.tracks)
    [D.tracks{r}, st] = tv.track.dropStill(D.tracks{r}, minPx, max(2, round(s.stillWindowS * rec.fps)));
    n = n + nnz(st);
end
end

function bad = raggedTrack(t, maxJump)
% a jump between consecutive points beyond maxJump px per frame and six times the track's usual
% step: the track hopped to an unrelated spot
f = double(t.frames(:));  bad = false;
if numel(f) < 4, return; end
st = sqrt(sum(diff(t.uv).^2, 2)) ./ diff(f);
bad = any(st > maxJump & st > 6 * median(st));
end

function P = findPoints(rec, D, s, bounces)
P.points = tv.events.pointsFromTracks(D.tracks, bounces, rec.fps, struct('gapS', s.pointGapS, 'minS', s.pointMinS, ...
    'splitS', s.pointSplitS, 'needsPlay', s.pointNeedsPlay, 'trackMinS', s.pointTrackMinS));
end

function C = findClips(rec, s)
if s.wholeFile
    % raw footage (Chris, 17 Nov): processed in windows of s.windowS seconds (so workers can
    % share it); the points are found afterwards from the tracks (findPoints)
    w = max(1, round(s.windowS * rec.fps));
    a = (0:w:rec.nFrames - 1)';
    C.clips = [a, min(a + w - 1, rec.nFrames - 1)];  C.cutT = zeros(0, 1);
    if s.maxWindows > 0, C.clips = C.clips(1:min(end, s.maxWindows), :); end   % a shorter test
else
    [C.clips, C.cutT] = tv.media.cuts(rec, s.clipOpts);
end
end

function img = blank(img, boxes)
for b = 1:size(boxes, 1)
    x0 = max(1, boxes(b, 1));  y0 = max(1, boxes(b, 2));
    x1 = min(size(img, 2), boxes(b, 3));  y1 = min(size(img, 1), boxes(b, 4));
    img(y0:y1, x0:x1, :) = 128;
end
end

function F = steadied(F, K, s)
% overlays blanked (they don't move with the camera), then lined up with the empty court
F = blank(F, s.overlayBoxes);
if s.steady, F = tv.calib.steady(F, K.bg, s.steadyMaxPx); end
end

function K = calibrate(rec, s)
% the empty court: median over the whole file (players move between clips)
bg = tv.calib.background(rec, 61, [], s.steady * s.steadyMaxPx);
bg = blank(bg, s.overlayBoxes);
h = s.hfovStart;
E = struct('name', 'single', 'aspect', 'any', 'hfov', h, 'vfov', 2 * atand(tand(h / 2) * rec.height / rec.width), ...
    'dfov', 2 * atand(tand(h / 2) * hypot(rec.width, rec.height) / rec.width), 'widthPx', rec.width, ...
    'heightPx', rec.height, 'model', 'rectilinear');
lens = tv.lens.atResolution(tv.lens.build(E, 'single', 'any'), rec.width, rec.height);
[K.cam, K.report] = tv.calib.courtFromLines(bg, lens, struct('lineOpts', s.lineOpts, 'fitFocal', true));
K.report = rmfield(K.report, intersect(fieldnames(K.report), {'lines'}));
K.corners = tv.calib.corners(K.cam);
K.bg = bg;
end

function [mask, opts] = detectSetup(rec, K, cfg, s)
% where the ball can be (overlays excluded) and the detector's options
c = tv.court.constants();
box = tv.court.interest(cfg.court);
mask = tv.detect.volumeMask(K.cam, box);
ov = blank(ones(rec.height, rec.width, 3), s.overlayBoxes);
mask = mask & ov(:, :, 1) == 1;
[gx, gy, gz] = ndgrid(box.x(1):1:box.x(2), box.y(1):1:box.y(2), 0:1:box.z(2));
pts = [gx(:), gy(:), gz(:)];
dmin = min(sqrt(sum((pts - K.cam.pos).^2, 2)));
dpx = 2 * c.ballRadius / dmin * tv.lens.pxPerRad(K.cam.lens);
opts = s.detectOpts;
if ~isfield(opts, 'maxArea'), opts.maxArea = max(30, pi / 4 * (2 * dpx)^2 * 3); end
end

function [D, total] = followAll(rec, clips, K, cfg, s, outDir, D)
% look again where each track predicts the ball (tv.track.follow); one file per clip, as detect
[mask, opts] = detectSetup(rec, K, cfg, s);
% not within s.steadyMaxPx of an overlay: shifting a frame onto the empty court moves the
% blanked boxes' edges, which the looser search took for balls (video 2)
ov = blank(ones(rec.height, rec.width), s.overlayBoxes) ~= 1;
mask = mask & ~imdilate(ov, true(2 * s.steadyMaxPx + 1));
fo = s.followOpts;  fn = fieldnames(opts);
for i = 1:numel(fn), if ~isfield(fo, fn{i}), fo.(fn{i}) = opts.(fn{i}); end, end
readF = @(a, n) cachedFrames(rec, K, s, a, n);
cd0 = fullfile(outDir, 'follow');  if ~exist(cd0, 'dir'), mkdir(cd0); end
total = 0;
for r = 1:size(clips, 1)
    cf = fullfile(cd0, sprintf('clip_%03d.mat', r));
    key = jsonencode({clips(r, :), numel(D.tracks{r}), arrayfun(@(t) double(t.frames(1)), D.tracks{r}), fo, ...
        s.steady, s.steadyMaxPx, s.dropPlayerTracks, s.playerTrackShare, s.stillMps, 'mask2', 'ovpad', 'flags'});
    if exist(cf, 'file')
        S = load(cf);
        if isfield(S, 'key') && strcmp(S.key, key), D.tracks{r} = S.trk; total = total + S.added; continue; end
    end
    cachedFrames();
    [trk, added] = tv.track.follow(D.tracks{r}, readF, K.bg, mask, clips(r, :), fo);
    save(cf, 'trk', 'added', 'key');
    D.tracks{r} = trk;  total = total + added;
end
end

function F = cachedFrames(rec, K, s, a, n)
% frames a..a+n-1, lined up with the empty court, from a cache of the last 120 read (each
% frame is read and steadied once though many tracks look at it); no arguments: empty it
persistent idx store
if nargin == 0, idx = [];  store = {};  return; end
if isempty(idx), idx = zeros(0, 1);  store = {}; end
want = a:a + n - 1;
miss = want(~ismember(want, idx));
if ~isempty(miss)
    G = steadied(tv.media.readFrames(rec, miss(1), miss(end) - miss(1) + 1), K, s);
    for j = 1:size(G, 4), idx(end+1, 1) = miss(1) + j - 1;  store{end+1, 1} = G(:, :, :, j); end %#ok<AGROW>
    if numel(idx) > 120, idx = idx(end-119:end);  store = store(end-119:end); end
end
F = zeros(rec.height, rec.width, 3, n, 'uint8');
for j = 1:n
    k = find(idx == want(j), 1, 'last');
    if ~isempty(k), F(:, :, :, j) = store{k}; end
end
end

function D = detectLearned(rec, clips, K, cfg, s, outDir)
% per clip: proposals, classifier scores and chains, in the empty court's pixels. With
% s.precomputed, the same detector's results are read from clip_NNN.csv there (columns frame, x,
% y, score, area, length, width, dmin, dmax, du, dv: x and y in the frame's own pixels, du and dv
% its shift against the empty court as tv.calib.steady gives it); otherwise worked out here.
S = tv.detect.ballSizeMap(K.cam, tv.court.interest(cfg.court));
ov = blank(ones(rec.height, rec.width), s.overlayBoxes) ~= 1;
S.mask = S.mask & ~ov;  S.dmax(ov) = 0;
net = [];
D.candidates = cell(size(clips, 1), 1);  D.tracks = cell(size(clips, 1), 1);
for r = 1:size(clips, 1)
    f0 = clips(r, 1);  f1 = clips(r, 2);
    pc = fullfile(s.precomputed, sprintf('clip_%03d.csv', r));
    if ~isempty(s.precomputed) && exist(pc, 'file')
        A = dlmread(pc, ',', 1, 0);
    else
        if isempty(net), net = tv.detect.loadBallNet(s.ballNetFile); end
        A = zeros(0, 11);  K2 = max(1, round(2 * rec.fps / 60));    % neighbours 1/30 s away
        for a = f0:30:f1
            first = max(0, a - K2);  n = min(30 + 2 * K2, rec.nFrames - first);
            F = tv.media.readFrames(rec, first, n);
            for t = a:min(a + 29, f1)
                j = t - first + 1;
                if j - K2 < 1 || j + K2 > size(F, 4), continue; end
                cur = F(:, :, :, j);
                C = tv.detect.motionProposals(F(:, :, :, j - K2), cur, F(:, :, :, j + K2), S);
                if isempty(C), continue; end
                prev = tv.calib.steady(F(:, :, :, j - K2), double(cur));  nxt = tv.calib.steady(F(:, :, :, j + K2), double(cur));
                ix = sub2ind(size(S.dmax), min(max(round(C(:, 2)), 1), rec.height), min(max(round(C(:, 1)), 1), rec.width));
                M = [S.dmin(ix), S.dmax(ix)];
                if size(net.conv(1).W, 3) == 5     % round 4: cut at the ball's scale, no colour
                    sc = tv.detect.ballScale(C(:, 5), M);
                    p = tv.detect.ballNet(net, tv.detect.ballCrops(prev, cur, nxt, C, 48, sc), M ./ sc);
                else
                    p = tv.detect.ballNet(net, tv.detect.ballCrops(prev, cur, nxt, C), M);
                end
                [~, d] = tv.calib.steady(cur, K.bg, s.steadyMaxPx);
                A = [A; repmat(t, size(C, 1), 1), C(:, 1:2), p(:), C(:, 3:5), M, repmat(d, size(C, 1), 1)]; %#ok<AGROW>
            end
        end
    end
    % into the empty court's pixels (where the camera fit and the bounce and player code work)
    rows = [A(:, 1), A(:, 2) - A(:, 10), A(:, 3) - A(:, 11), A(:, 4), A(:, 8:9)];
    D.candidates{r} = rows;
    co = s.chainOpts;  if ~isfield(co, 'fps'), co.fps = rec.fps; end
    [T, val] = tv.track.chains(rows(rows(:, 4) > 0.05, :), co);
    D.tracks{r} = tv.track.inPlay(T, val);              % one ball in play at a time
end
end

function D = detectAll(rec, clips, K, cfg, s, outDir)
[mask, opts] = detectSetup(rec, K, cfg, s);
list = s.clipList;  if isempty(list), list = 1:size(clips, 1); end
cd0 = fullfile(outDir, 'clips');  if ~exist(cd0, 'dir'), mkdir(cd0); end
D.candidates = cell(size(clips, 1), 1);  D.tracks = cell(size(clips, 1), 1);
for r = list(:)'
    % each clip is saved as it finishes, so parallel workers and restarts share the work
    % (a clip file is reused only when it was made with the same settings)
    cf = fullfile(cd0, sprintf('clip_%03d.mat', r));
    f0 = clips(r, 1);  f1 = clips(r, 2);
    key = jsonencode({f0, f1, s.overlayBoxes, cfg.court, K.cam.pos, opts, s.steady, s.steadyMaxPx, cfg.chunk, 'mask2'});
    if exist(cf, 'file')
        S = load(cf);
        if isfield(S, 'key') && strcmp(S.key, key), D.candidates{r} = S.cand; D.tracks{r} = S.trk; continue; end
    end
    cand = zeros(0, 6);
    for a = f0:cfg.chunk:f1
        first = max(f0, a - 1);
        n = min(cfg.chunk + 2, f1 - first + 1);
        F = tv.media.readFrames(rec, first, n);
        if size(F, 4) < 3, continue; end
        F = steadied(F, K, s);
        Ck = tv.detect.ballCandidates(F, K.bg, mask, opts);
        Ck(:, 1) = Ck(:, 1) + first - 1;
        cand = [cand; Ck(Ck(:, 1) >= a & Ck(:, 1) < a + cfg.chunk, :)]; %#ok<AGROW>
    end
    trk = tv.track.ball2d(cand);
    D.candidates{r} = cand;  D.tracks{r} = trk;
    save(cf, 'cand', 'trk', 'key');
end
end

function B = findBounces(rec, D, K, s, PO, box)
% a bounce: the track falls (image row increasing) then rises, with the turn away from people
c = tv.court.constants();
B.bounces = struct('clip', {}, 'frame', {}, 't', {}, 'u', {}, 'v', {}, 'x', {}, 'y', {}, 'call', {}, 'marginM', {}, 'track', {});
nHit = 0;  nNet = 0;
for r = 1:numel(D.tracks)
    for ti = 1:numel(D.tracks{r})
        trk = D.tracks{r}(ti);
        f = double(trk.frames(:));  v = double(trk.uv(:, 2));  u = double(trk.uv(:, 1));
        if isfield(trk, 'followed')
            % the detector's own points only: a turn needs its evidence, not the looser search's
            own = ~trk.followed;  f = f(own);  u = u(own);  v = v(own);
        end
        if numel(f) < 7, continue; end
        vs = smoothdata1(v, 3);
        dv = diff(vs) ./ diff(f);
        for i = 3:numel(dv) - 2
            if mean(dv(i - 2:i)) > s.bounceMinPx && mean(dv(i + 1:i + 2)) < -s.bounceMinPx
                j = i + 1;
                ray = tv.camera.rays(K.cam, [u(j), v(j)]);
                if ray(3) >= 0, continue; end
                sc = (c.ballRadius - K.cam.pos(3)) / ray(3);
                g = K.cam.pos + sc * ray;
                if inNetBand(K.cam, [u(j), v(j)]), nNet = nNet + 1; continue; end
                if s.bounceSkipHits && atPlayer(PO, s, f(j), [u(j), v(j)])
                    nHit = nHit + 1;  continue
                end
                [call, m] = callSingles(g(1:2), c);
                B.bounces(end+1) = struct('clip', r, 'frame', f(j), 't', rec.pts(f(j) + 1), 'u', u(j), 'v', v(j), ...
                    'x', g(1), 'y', g(2), 'call', call, 'marginM', m, 'track', ti); %#ok<AGROW>
            end
        end
    end
end
% one bounce seen twice (two tracks, or two turns of one) within s.bounceMergeS: keep the first
keep = true(1, numel(B.bounces));
for a = 1:numel(B.bounces)
    for b = 1:a - 1
        if keep(b) && B.bounces(a).clip == B.bounces(b).clip && abs(B.bounces(a).t - B.bounces(b).t) < s.bounceMergeS ...
                && hypot(B.bounces(a).u - B.bounces(b).u, B.bounces(a).v - B.bounces(b).v) < 40
            keep(a) = false;  break
        end
    end
end
B.duplicates = nnz(~keep);
B.bounces = B.bounces(keep);
% in play, bounced on the spot (a server's dribble) or on the next court (tv.events.bounceKind)
if isempty(B.bounces)
    B.bounces = struct('clip', {}, 'frame', {}, 't', {}, 'u', {}, 'v', {}, 'x', {}, 'y', {}, 'call', {}, 'marginM', {}, 'track', {}, 'kind', {}, 'cameM', {});
    B.hitsSkipped = nHit;  B.netSkipped = nNet;  return
end
[B.bounces.kind] = deal('play');  [B.bounces.cameM] = deal(NaN);
for r = unique([B.bounces.clip])
    P = zeros(0, 3);
    for trk = D.tracks{r}(:)', P = [P; double(trk.frames(:)), double(trk.uv)]; end %#ok<AGROW>
    i = find([B.bounces.clip] == r);
    [kd, cm] = tv.events.bounceKind(K.cam, B.bounces(i), P, rec.fps, box, s.bounceKindOpts);
    for j = 1:numel(i), B.bounces(i(j)).kind = kd{j};  B.bounces(i(j)).cameM = cm(j); end
end
B.hitsSkipped = nHit;  B.netSkipped = nNet;
end

function in = inNetBand(cam, p)
% the ball turning against the net (between the tape and the ground under it, posts included)
% hit the net; it is not a bounce
c = tv.court.constants();
y = linspace(-c.postY, c.postY, 60)';
[top, ok1] = tv.camera.project(cam, [zeros(60, 1), y, tv.court.netHeight(y)]);
[bot, ok2] = tv.camera.project(cam, [zeros(60, 1), y, zeros(60, 1)]);
in = false;
if nnz(ok1 & ok2) < 2, return; end
top = top(ok1 & ok2, :);  bot = bot(ok1 & ok2, :);
if p(1) < min(top(:, 1)) || p(1) > max(top(:, 1)), return; end
vt = interp1(top(:, 1), top(:, 2), p(1));  vb = interp1(bot(:, 1), bot(:, 2), p(1));
in = p(2) >= vt - 3 && p(2) <= vb;
end

function hit = atPlayer(PO, s, frame, p)
% a turn of the ball at a person, above knee height, is a hit (racquet), not a bounce: the
% ball is inside the person's outline (the nearest sample of the outlines stage), widened by
% s.hitReach of its width each side (arm and racquet) and 10% of its height, and higher than
% the bottom quarter of it (the feet, where a ball can bounce beside them)
[d, j] = min(abs(PO.frames - frame));
hit = false;
if isempty(j) || d > max(diff(PO.frames(1:min(2, end)))), return; end
b = widen(PO.raw{j}, s, 0.75);
hit = ~isempty(b) && any(p(1) >= b(:, 1) & p(1) <= b(:, 3) & p(2) >= b(:, 2) & p(2) <= b(:, 4));
end

function b = widen(raw, s, below)
% person boxes [u0 v0 u1 v1] widened by s.hitReach of their width each side and 10% of their
% height above, cut at the fraction `below` of their height
w = raw(:, 3) - raw(:, 1);  h = raw(:, 4) - raw(:, 2);
b = [raw(:, 1) - s.hitReach * w, raw(:, 2) - 0.1 * h, raw(:, 3) + s.hitReach * w, raw(:, 2) + below * h];
end

function b = people(img, bgc, s)
% people: large upright shapes against the clip's own empty court (bgc), as [u0 v0 u1 v1].
% Each clip has its own empty court (the median of frames across it) because on video 1 the
% evening light changed whole areas against the file's: the "people" covered half the frame.
fg = sum(abs(double(img) - double(bgc)), 3) > 60;
fg = imclose(imopen(fg, true(3)), true(15));
st = regionprops(bwlabel(fg, 8), 'BoundingBox', 'Area');
b = zeros(0, 4);
for i = 1:numel(st)
    bb = st(i).BoundingBox;
    if st(i).Area < s.personMinArea || bb(4) < 0.8 * bb(3) || bb(3) * bb(4) > numel(fg) / 8, continue; end
    b(end+1, :) = [bb(1), bb(2), bb(1) + bb(3), bb(2) + bb(4)]; %#ok<AGROW>
end
end

function P = playerOutlines(rec, clips, K, s)
% the people every s.playerTrackStepS in every clip (raw boxes; widened where used)
step = max(1, round(s.playerTrackStepS * rec.fps));
P.frames = zeros(0, 1);  P.raw = {};
for r = 1:size(clips, 1)
    sample = unique(round(linspace(clips(r, 1), clips(r, 2), 15)));
    B = zeros(rec.height, rec.width, 3, numel(sample), 'uint8');
    for q = 1:numel(sample), B(:, :, :, q) = steadied(tv.media.readFrames(rec, sample(q), 1), K, s); end
    bgc = median(B, 4);
    want = clips(r, 1):step:clips(r, 2);
    for a = clips(r, 1):30:clips(r, 2)
        n = min(30, clips(r, 2) - a + 1);
        fs = want(want >= a & want < a + n);
        if isempty(fs), continue; end
        F = tv.media.readFrames(rec, a, n);
        for f = fs
            P.frames(end+1, 1) = f;
            P.raw{end+1, 1} = people(steadied(F(:, :, :, f - a + 1), K, s), bgc, s);
        end
    end
end
end

function y = smoothdata1(x, w)
y = conv(x, ones(w, 1) / w, 'same');
y(1) = x(1);  y(end) = x(end);
end

function [call, m] = callSingles(xy, c)
% distance inside (+) or outside (-) the singles court's outer line edges, metres
mx = c.halfLength - abs(xy(1));  my = c.halfSingles - abs(xy(2));
m = min(mx, my);
call = 'in';  if m < -c.ballRadius, call = 'out'; end
end

function Y = trackPlayers(rec, clips, K, s)
Y.samples = struct('clip', {}, 't', {}, 'dets', {});
for r = 1:size(clips, 1)
    for f = clips(r, 1):round(rec.fps / s.playerHz):clips(r, 2)
        img = steadied(tv.media.readFrames(rec, f, 1), K, s);
        dets = tv.players.detect(img, K.bg, K.cam, struct('heightRange', [1.2 2.4]));
        Y.samples(end+1) = struct('clip', r, 't', rec.pts(f + 1), 'dets', dets); %#ok<AGROW>
    end
end
end
