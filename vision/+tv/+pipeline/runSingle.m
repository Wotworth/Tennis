function R = runSingle(file, outDir, cfg)
%RUNSINGLE  One camera, one edited video: the earliest real-footage test (Chris, 17 Nov).
%   For footage from a single camera (a phone, the HERO7 trial, one MISSION 1 PRO alone): no
%   3D flights, speeds or spin, which need two cameras. Stages (each saved and skipped when
%   unchanged, tv.pipeline.stage):
%     probe     frame times (TV-ING-10)
%     clips     the clips of an edited "included rallies" export (tv.media.cuts); a whole
%               recording is one clip
%     calib     the empty court (background), its lines, and the camera's pose and, for an
%               uncalibrated lens, focal length, from the court's line pattern alone
%               (tv.calib.courtFromLines); court corners out of view (TV-CAL-20)
%     detect    ball candidates and 2D tracks in every clip (TV-DET, TV-TRK); each frame is
%               first lined up with the empty court when the camera moved (steady,
%               tv.calib.steady, TV-CAL-14), as are the frames the hit and player checks use
%     bounces   where a 2D track turns from falling to rising away from any player: a bounce,
%               placed on the ground through the camera; in or out of the singles court.
%               A turn inside a person's outline (widened by hitReach for the racquet) above
%               knee height is a hit, and one against the net hit the net: both skipped
%               (bounceSkipHits; personMinArea px). One bounce seen twice within bounceMergeS
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
           'steady', true, 'steadyMaxPx', 40);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(s, fn{k}), s.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
dd = dir(file);
key0 = sprintf('%s|%d|%s', file, dd.bytes, dd.date);
k = @(varargin) [key0 '|' jsonencode(varargin)];

P = tv.pipeline.stage(outDir, 'probe', k(), @() tv.media.probe(file));
rec = P;
C = tv.pipeline.stage(outDir, 'clips', k(s.clipOpts, s.wholeFile), @() findClips(rec, s));
K = tv.pipeline.stage(outDir, 'calib', k(s.overlayBoxes, s.lineOpts, s.hfovStart), @() calibrate(rec, s));
if ~isempty(K.corners.text) && isfield(cfg, 'notify'), cfg.notify('Camera framing', K.corners.text); end
if s.detectOnly
    % a worker: detect the clips in s.clipList only (each saved as it finishes), then stop
    detectAll(rec, C.clips, K, cfg, s, outDir);  R = [];  return
end
s.clipList = [];
D = tv.pipeline.stage(outDir, 'detect', k(C.clips, s.overlayBoxes, cfg.court, K.cam.pos, s.detectOpts, s.steady, s.steadyMaxPx), @() detectAll(rec, C.clips, K, cfg, s, outDir));
[D, nStill] = dropStillTracks(D, rec, K, cfg, s);
B = tv.pipeline.stage(outDir, 'bounces', k(s.bounceMinPx, K.cam.pos, s.stillMps, s.stillWindowS, s.bounceSkipHits, s.personMinArea, s.hitReach, s.bounceMergeS, s.steady, 3), @() findBounces(rec, D, K, s));
Y = tv.pipeline.stage(outDir, 'players', k(s.playerHz, C.clips, K.cam.pos, s.steady), @() trackPlayers(rec, C.clips, K, s));
R = struct('rec', rec, 'clips', C.clips, 'cutT', C.cutT, 'cam', K.cam, 'calib', K.report, 'corners', K.corners, ...
    'bg', K.bg, 'overlayBoxes', s.overlayBoxes, 'candidates', {D.candidates}, 'tracks', {D.tracks}, ...
    'bounces', B.bounces, 'bounceSkips', struct('hits', B.hitsSkipped, 'net', B.netSkipped, 'duplicates', B.duplicates), 'players', Y.samples, 'stillTracks', nStill, 'stillMps', s.stillMps);
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

function C = findClips(rec, s)
if s.wholeFile
    C.clips = [0, rec.nFrames - 1];  C.cutT = zeros(0, 1);
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
bg = tv.calib.background(rec, 61);
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

function D = detectAll(rec, clips, K, cfg, s, outDir)
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
list = s.clipList;  if isempty(list), list = 1:size(clips, 1); end
cd0 = fullfile(outDir, 'clips');  if ~exist(cd0, 'dir'), mkdir(cd0); end
D.candidates = cell(size(clips, 1), 1);  D.tracks = cell(size(clips, 1), 1);
for r = list(:)'
    % each clip is saved as it finishes, so parallel workers and restarts share the work
    % (a clip file is reused only when it was made with the same settings)
    cf = fullfile(cd0, sprintf('clip_%03d.mat', r));
    f0 = clips(r, 1);  f1 = clips(r, 2);
    key = jsonencode({f0, f1, s.overlayBoxes, cfg.court, K.cam.pos, opts, s.steady, s.steadyMaxPx, cfg.chunk});
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

function B = findBounces(rec, D, K, s)
% a bounce: the track falls (image row increasing) then rises, with the turn away from people
c = tv.court.constants();
B.bounces = struct('clip', {}, 'frame', {}, 't', {}, 'u', {}, 'v', {}, 'x', {}, 'y', {}, 'call', {}, 'marginM', {});
nHit = 0;  nNet = 0;
for r = 1:numel(D.tracks)
    for trk = D.tracks{r}(:)'
        f = double(trk.frames(:));  v = trk.uv(:, 2);  u = trk.uv(:, 1);
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
                if s.bounceSkipHits && atPlayer(rec, K, s, f(j), [u(j), v(j)])
                    nHit = nHit + 1;  continue
                end
                [call, m] = callSingles(g(1:2), c);
                B.bounces(end+1) = struct('clip', r, 'frame', f(j), 't', rec.pts(f(j) + 1), 'u', u(j), 'v', v(j), ...
                    'x', g(1), 'y', g(2), 'call', call, 'marginM', m); %#ok<AGROW>
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

function hit = atPlayer(rec, K, s, frame, p)
% a turn of the ball at a person, above knee height, is a hit (racquet), not a bounce: the
% ball is inside the person's outline (the frame against the empty court), widened by
% s.hitReach of its width each side (arm and racquet) and 10% of its height, and higher than
% the bottom quarter of it (the feet, where a ball can bounce beside them)
img = double(steadied(tv.media.readFrames(rec, frame, 1), K, s));
fg = sum(abs(img - K.bg), 3) > 60;
fg = imclose(imopen(fg, true(3)), true(15));
L = bwlabel(fg, 8);
st = regionprops(L, 'BoundingBox', 'Area');
hit = false;
for i = 1:numel(st)
    if st(i).Area < s.personMinArea, continue; end
    bb = st(i).BoundingBox;  pad = [s.hitReach * bb(3), 0.1 * bb(4)];
    inX = p(1) >= bb(1) - pad(1) && p(1) <= bb(1) + bb(3) + pad(1);
    inY = p(2) >= bb(2) - pad(2) && p(2) <= bb(2) + 0.75 * bb(4);
    if inX && inY, hit = true; return; end
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
