function O = observe(S, cams, opts)
%OBSERVE  What each camera's ball detector would report for a study session (TV-TST-01, no video).
%   For every frame of camera k inside a rally window: the frame's truth
%   time from the camera's clock (offset and drift), the exposure moment of
%   the ball's own image row (rolling shutter: readout * (row - 1) / height,
%   plus half the shutter), the ball's truth position then, projected through
%   the camera; plus detector noise (opts.sigmaPx), random misses
%   (opts.dropout) and the ball hidden around each contact by the player
%   (opts.hideMs either side, in one camera or the other).
%   One camera blocked (Chris, 18 Nov): for a share opts.blockShare of the shots, one camera
%   (picked at random) reports nothing for part of the shot. opts.blockWhere: 'part' (a
%   stretch opts.blockFrac of the flight from the hit to the bounce, placed at random),
%   'beforeBounce' (that whole flight), 'afterBounce' (the bounce to the next hit) or
%   'whole' (both). O.blocks rows: [shot number in S.shots, camera, from, to] (truth times).
%   O.tracks{r, k}  struct (frames 0-based, uv) per rally and camera
%   O.rec(k)        pts, height, width, nFrames (file times from each camera's first frame)
%   O.sync0         the coarse timing the pipeline starts from (start times to the
%                   millisecond, readout from the prior), as tv.pipeline.run builds it
%   O.cams          the camera poses the pipeline would use: the truth knocked off
%                   by calibration-sized errors (opts.posErrM, opts.rotErrDeg)
if nargin < 3, opts = struct(); end
d = struct('sigmaPx', 0.5, 'dropout', 0.05, 'hideMs', 25, 'posErrM', 0.01, 'rotErrDeg', 0.04, ...
           'readoutPrior', 0.008, 'shutter', 1 / 1920, 'blockShare', 0, 'blockWhere', 'part', 'blockFrac', 0.5, 'blockSeed', 1, ...
           'errModel', [], 'hitMs', 60);
% opts.errModel (tv.synth.detectorModel, 20 Nov): the detector's measured recall and centre error by
%   the ball's size in the picture, in place of sigmaPx and dropout. The size comes from the ball's
%   distance to the camera and the lens. With errModel.hit (22 Nov), frames within opts.hitMs of a
%   hit use the detector's behaviour round a contact (strings, bodies, heads) instead.
%   RETUNE(real footage): hitMs.
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
tHits = [];  if ~isempty(S.shots), tHits = [S.shots.tHit]; end
O.tracks = cell(size(S.windows, 1), 2);
% blocked stretches, chosen without touching the random-number state (so the noise and the
% misses are the same with and without them)
O.blocks = zeros(0, 4);
for j = 1:numel(S.shots) * (opts.blockShare > 0)
    s = S.shots(j);
    u = mod(sin((j + 31 * opts.blockSeed) * [12.9898 78.233 39.3468]) * 43758.5453, 1);     % three numbers in 0..1 per shot
    if u(1) >= opts.blockShare || isnan(s.tBounce), continue; end
    tNext = s.tBounce + s.toNextHit;  if isnan(tNext), tNext = s.tBounce + 0.8; end
    switch opts.blockWhere
        case 'beforeBounce', w = [s.tHit, s.tBounce];
        case 'afterBounce',  w = [s.tBounce, tNext];
        case 'whole',        w = [s.tHit, tNext];
        otherwise,           w = s.tHit + (s.tBounce - s.tHit) * (u(3) * (1 - opts.blockFrac) + [0, opts.blockFrac]);
    end
    O.blocks(end+1, :) = [j, 1 + (u(2) < 0.5), w]; %#ok<AGROW>
end
for k = 1:2
    cam = cams(k);  H = cam.height;
    tEndAll = S.windows(end, 2) + 5;
    N = ceil((tEndAll - tv.synth.truthTime(cam, cam.recordStart)) * cam.fps) + 1;
    pts = (0:N - 1)' / cam.fps;
    Tframe = tv.synth.truthTime(cam, cam.recordStart + pts);
    O.rec(k) = struct('pts', pts, 'height', H, 'width', cam.width, 'nFrames', N);
    hideCam = 1 + (rand(size(tHits)) < 0.5);
    for r = 1:size(S.windows, 1)
        n = find(Tframe >= S.windows(r, 1) & Tframe <= S.windows(r, 2));
        uv = nan(numel(n), 2);
        v = H / 2 * ones(numel(n), 1);
        for it = 1:3      % the ball's row decides when it was exposed
            Te = Tframe(n) + cam.readout * (v - 1) / H + opts.shutter / 2;
            B = ballAt(S.pieces{r}, Te);
            ok = all(isfinite(B), 2);
            [px, okp] = tv.camera.project(cam, B(ok, :));
            uv(:) = NaN;  tmp = nan(nnz(ok), 2);  tmp(okp, :) = px(okp, :);  uv(ok, :) = tmp;
            v(isfinite(uv(:, 2))) = uv(isfinite(uv(:, 2)), 2);
        end
        if isempty(opts.errModel)
            keep = all(isfinite(uv), 2) & rand(numel(n), 1) > opts.dropout;
            sig = opts.sigmaPx * ones(numel(n), 1);
        else
            Bm = ballAt(S.pieces{r}, Te);
            dpx = 2 * 0.0335 ./ sqrt(sum((Bm - cam.pos) .^ 2, 2)) * tv.lens.pxPerRad(cam.lens);
            em = opts.errModel;  dq = min(max(dpx, min(em.d)), max(em.d));  dq(~isfinite(dq)) = min(em.d);
            rec = interp1(em.d, em.recall, dq);  sig = interp1(em.d, em.sigma, dq);
            if isfield(em, 'hit') && ~isempty(tHits)
                near = min(abs(Te - tHits), [], 2) <= opts.hitMs / 1000;
                hq = min(max(dq, min(em.hit.d)), max(em.hit.d));
                rec(near) = interp1(em.hit.d, em.hit.recall, hq(near));  sig(near) = interp1(em.hit.d, em.hit.sigma, hq(near));
            end
            keep = all(isfinite(uv), 2) & rand(numel(n), 1) < rec;
        end
        for j = find(hideCam == k)
            keep = keep & abs(Te - tHits(j)) > opts.hideMs / 1000;
        end
        for b = O.blocks(O.blocks(:, 2) == k, :)'
            keep = keep & ~(Te >= b(3) & Te <= b(4));
        end
        uv = uv + sig .* randn(size(uv));
        O.tracks{r, k} = struct('frames', n(keep) - 1, 'uv', uv(keep, :));
    end
end
% the pipeline's starting point (tv.pipeline.run probeBoth, then sync from rays)
off = round(1000 * (tv.synth.truthTime(cams(2), cams(2).recordStart) - tv.synth.truthTime(cams(1), cams(1).recordStart))) / 1000;
O.sync0 = struct('startOffset', [0 off], 'delta', 0, 'drift', 0, 'tref', O.rec(1).pts(end) / 2, ...
    'readout', opts.readoutPrior * [1 1], 'shutter', opts.shutter);
% calibration-sized pose errors
O.cams = cams;
for k = 1:2
    e = randn(1, 3);  O.cams(k).pos = cams(k).pos + opts.posErrM * e / norm(e);
    a = randn(1, 3);  a = a / norm(a);  th = deg2rad(opts.rotErrDeg);
    K = [0 -a(3) a(2); a(3) 0 -a(1); -a(2) a(1) 0];
    O.cams(k).R = cams(k).R * (eye(3) + sin(th) * K + (1 - cos(th)) * K^2);
end
end

function B = ballAt(fl, T)
% the ball's truth position at times T (NaN when no flight covers T)
B = nan(numel(T), 3);
for f = fl(:)'
    in = T >= f.t(1) & T <= f.t(end);
    if any(in) && numel(f.t) > 1, B(in, :) = interp1(f.t, f.P, T(in)); end
end
end
