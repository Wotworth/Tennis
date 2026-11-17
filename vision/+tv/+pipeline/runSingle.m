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
%     detect    ball candidates and 2D tracks in every clip (TV-DET, TV-TRK)
%     bounces   where a 2D track turns from falling to rising away from any player: a bounce,
%               placed on the ground through the camera; in or out of the singles court
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
           'detectOpts', struct(), 'clipList', [], 'detectOnly', false, 'stillMps', 1.5, 'stillWindowS', 0.25);
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
D = tv.pipeline.stage(outDir, 'detect', k(C.clips, s.overlayBoxes, cfg.court, K.cam.pos, s.detectOpts), @() detectAll(rec, C.clips, K, cfg, s, outDir));
[D, nStill] = dropStillTracks(D, rec, K, cfg, s);
B = tv.pipeline.stage(outDir, 'bounces', k(s.bounceMinPx, K.cam.pos, s.stillMps, s.stillWindowS), @() findBounces(rec, D, K, s));
Y = tv.pipeline.stage(outDir, 'players', k(s.playerHz, C.clips, K.cam.pos), @() trackPlayers(rec, C.clips, K, s));
R = struct('rec', rec, 'clips', C.clips, 'cutT', C.cutT, 'cam', K.cam, 'calib', K.report, 'corners', K.corners, ...
    'bg', K.bg, 'overlayBoxes', s.overlayBoxes, 'candidates', {D.candidates}, 'tracks', {D.tracks}, ...
    'bounces', B.bounces, 'players', Y.samples, 'stillTracks', nStill, 'stillMps', s.stillMps);
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
    cf = fullfile(cd0, sprintf('clip_%03d.mat', r));
    if exist(cf, 'file'), S = load(cf); D.candidates{r} = S.cand; D.tracks{r} = S.trk; continue; end
    f0 = clips(r, 1);  f1 = clips(r, 2);
    cand = zeros(0, 6);
    for a = f0:cfg.chunk:f1
        first = max(f0, a - 1);
        n = min(cfg.chunk + 2, f1 - first + 1);
        F = tv.media.readFrames(rec, first, n);
        if size(F, 4) < 3, continue; end
        Ck = tv.detect.ballCandidates(F, K.bg, mask, opts);
        Ck(:, 1) = Ck(:, 1) + first - 1;
        cand = [cand; Ck(Ck(:, 1) >= a & Ck(:, 1) < a + cfg.chunk, :)]; %#ok<AGROW>
    end
    trk = tv.track.ball2d(cand);
    D.candidates{r} = cand;  D.tracks{r} = trk;
    save(cf, 'cand', 'trk');
end
end

function B = findBounces(rec, D, K, s)
% a bounce: the track falls (image row increasing) then rises, with the turn away from people
c = tv.court.constants();
B.bounces = struct('clip', {}, 'frame', {}, 't', {}, 'u', {}, 'v', {}, 'x', {}, 'y', {}, 'call', {}, 'marginM', {});
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
                [call, m] = callSingles(g(1:2), c);
                B.bounces(end+1) = struct('clip', r, 'frame', f(j), 't', rec.pts(f(j) + 1), 'u', u(j), 'v', v(j), ...
                    'x', g(1), 'y', g(2), 'call', call, 'marginM', m); %#ok<AGROW>
            end
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
        img = tv.media.readFrames(rec, f, 1);
        img = blank(img, s.overlayBoxes);
        dets = tv.players.detect(img, K.bg, K.cam, struct('heightRange', [1.2 2.4]));
        Y.samples(end+1) = struct('clip', r, 't', rec.pts(f + 1), 'dets', dets); %#ok<AGROW>
    end
end
end
