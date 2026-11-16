function [kept, log] = gateTracks(tracks, cands, cams, rec, sync, box, opts)
%GATETRACKS  Keep only the ball on Chris's court (TV-ADJ-02 to 04, 06), one rally.
%   tracks: 1-by-2 cell of 2D tracks per camera (tv.track.ball2d); cands: 1-by-2
%   cell of that rally's candidates [frame u v ...] (for the isolated ones).
%   Needs the timing (TV-SYNC-02) and the calibration.
%
%   1. Stereo pairing (TV-ADJ-02). Each track point of one camera is paired with
%      the other camera's tracks running at its moment: that track's pixel is
%      interpolated to the same time (never frames paired by index), the two
%      sight lines are triangulated and the point projected back into both
%      cameras. The summed reprojection error is the epipolar test (a sight-line
%      pair that does not meet cannot be one ball). The other camera's track
%      with the lowest error is the partner; above opts.epipolarPx the pair is
%      rejected ("epipolar fail") and the point stays a one-camera point.
%   2. Volume gate (TV-ADJ-03): a paired point whose 3D position is outside
%      the court of interest is rejected ("outside court of interest").
%   3. Track filter (TV-ADJ-04). A track is dropped as a whole when
%      - fewer than opts.minPairedFrac of its points have a partner ("no stereo partner");
%      - fewer than opts.minInsideFrac of its paired points are inside ("mostly outside":
%        a neighbour's ball, even if it rolls onto Chris's court);
%      and in a kept track, a paired point that moves faster than opts.maxSpeed
%      from the previous one is dropped ("implausible jump").
%   3b. Where two kept tracks of one camera overlap in time, the one that matches the
%      other camera worse there gives up those points ("overlaps a better track").
%   4. Candidates that are in no track are logged "isolated".
%   The flight fit (tv.recon.segments) then drops what no physical flight
%   explains ("implausible flight", logged by the pipeline).
%
%   kept: 1-by-2 cell of the kept tracks (points removed as above).
%   log: struct array, one row per rejected candidate: cam, frame, u, v, t,
%   X (1-by-3, NaN if never triangulated), track (that camera's track id, 0 if
%   none), reason, errPx.
%   RETUNE(real footage): every opts value (tv.pipeline.defaults, cfg.gate).
if nargin < 7, opts = struct(); end
d = struct('epipolarPx', 4, 'minInsideFrac', 0.5, 'minPairedFrac', 0.3, 'maxSpeed', 75, 'maxGapFrames', 3);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
log = emptyLog();
kept = {tracks{1}([]), tracks{2}([])};
% times of every track point
T = cell(1, 2);
for k = 1:2
    for j = 1:numel(tracks{k})
        T{k}{j} = tv.recon.detTimes(k, double(tracks{k}(j).frames(:)), tracks{k}(j).uv(:, 2), rec, sync);
    end
end
% 1-2: pair every point with the other camera's tracks. Tracks are matched first
% (TV-REC-02): the other camera's track with the lowest median error over their
% shared time is the partner, so a stray that happens to lie on a sight line
% (a perfect but wrong pair for one point) cannot steal it. A point that does not
% fit its partner may pair with another track (a 2D tracker that swapped onto
% the neighbour's ball for a few frames: those points then land outside).
info = cell(1, 2);
for k = 1:2
    o = 3 - k;
    fps = 1 / median(diff(rec(o).pts));
    for j = 1:numel(tracks{k})
        trk = tracks{k}(j);  n = numel(trk.frames);
        E = inf(n, numel(tracks{o}));  XX = nan(n, 3, numel(tracks{o}));  covered = false(n, 1);
        for jj = 1:numel(tracks{o})
            [E(:, jj), XX(:, :, jj), cov] = pairWith(k, trk, T{k}{j}, tracks{o}(jj), T{o}{jj}, cams, fps, opts);
            covered = covered | cov;
        end
        best = inf(n, 1);  X = nan(n, 3);
        if ~isempty(E)
            med = arrayfun(@(jj) medFinite(E(:, jj)), 1:size(E, 2));
            [mp, partner] = min(med);
            [emin, imin] = min(E, [], 2);
            usePartner = isfinite(mp) & mp <= opts.epipolarPx & E(:, partner) <= opts.epipolarPx;
            pick = imin;  pick(usePartner) = partner;
            for m = 1:n
                best(m) = E(m, pick(m));  X(m, :) = XX(m, :, pick(m));
            end
            best(~usePartner) = emin(~usePartner);
        end
        st = repmat({'unpaired'}, n, 1);
        st(covered) = {'epipolar fail'};
        paired = best <= opts.epipolarPx;
        st(paired) = {'ok'};
        out = paired & ~tv.court.inInterest(X, box);
        st(out) = {'outside court of interest'};
        info{k}{j} = struct('status', {st}, 'X', X, 'err', best);
    end
end
% 3: track decisions
keptErr = {{}, {}};  keptT = {{}, {}};
for k = 1:2
    for j = 1:numel(tracks{k})
        trk = tracks{k}(j);  I = info{k}{j};  t = T{k}{j};
        paired = ismember(I.status, {'ok', 'outside court of interest'});
        inside = strcmp(I.status, 'ok');
        reason = '';
        if nnz(paired) < opts.minPairedFrac * numel(paired)
            reason = 'no stereo partner';
        elseif nnz(inside) < opts.minInsideFrac * nnz(paired)
            reason = 'mostly outside';
        end
        if ~isempty(reason)
            log = addRows(log, k, trk, t, I, 1:numel(t), reason);
            continue
        end
        % implausible jumps between neighbouring inside points (time order)
        drop = ~inside & paired;                      % outside points
        [ts, o] = sort(t);  ii = o(inside(o));
        last = [];
        for m = ii(:)'
            if ~isempty(last)
                v = norm(I.X(m, :) - I.X(last, :)) / max(t(m) - t(last), 1e-4);
                if v > opts.maxSpeed, drop(m) = true; I.status{m} = 'implausible jump'; continue; end
            end
            last = m;
        end
        log = addRows(log, k, trk, t, I, find(drop), '');
        % epipolar fails stay in the track as one-camera points; logged as such
        ef = find(strcmp(I.status, 'epipolar fail'));
        log = addRows(log, k, trk, t, I, ef, 'epipolar fail (kept, one camera)');
        trk.frames = trk.frames(~drop);  trk.uv = trk.uv(~drop, :);  trk.area = trk.area(~drop);
        if numel(trk.frames) >= 3
            kept{k}(end+1) = trk; %#ok<AGROW>
            keptErr{k}{end+1} = I.err(~drop); %#ok<AGROW>
            keptT{k}{end+1} = t(~drop); %#ok<AGROW>
        end
    end
end
% 3b: two kept tracks of one camera that overlap in time (a tracker that started a second track
% on a blob by the player just before a hit): over the overlap, the track that matches the other
% camera worse gives up its points ("overlaps a better track"), so the ball's track has clean ends
for k = 1:2
    changed = true;
    while changed
        changed = false;
        for a = 1:numel(kept{k})
            for b = a + 1:numel(kept{k})
                ta = keptT{k}{a};  tb = keptT{k}{b};
                % a track emptied by an earlier overlap has nothing left to give up
                if isempty(ta) || isempty(tb), continue; end
                lo = max(min(ta), min(tb));  hi = min(max(ta), max(tb));
                if lo >= hi, continue; end
                ia = ta >= lo & ta <= hi;  ib = tb >= lo & tb <= hi;
                ea = median(min(keptErr{k}{a}(ia), 1e3));  eb = median(min(keptErr{k}{b}(ib), 1e3));
                if ea <= eb, lose = b; m = ib; else, lose = a; m = ia; end
                if ~any(m), continue; end
                trk = kept{k}(lose);  I = struct('status', {repmat({'overlaps a better track'}, numel(m), 1)}, ...
                    'X', nan(numel(m), 3), 'err', keptErr{k}{lose});
                log = addRows(log, k, trk, keptT{k}{lose}, I, find(m), '');
                trk.frames = trk.frames(~m);  trk.uv = trk.uv(~m, :);  trk.area = trk.area(~m);
                kept{k}(lose) = trk;  keptErr{k}{lose} = keptErr{k}{lose}(~m);  keptT{k}{lose} = keptT{k}{lose}(~m);
                changed = true;  break
            end
            if changed, break; end
        end
    end
    short = arrayfun(@(x) numel(x.frames) < 3, kept{k});
    kept{k} = kept{k}(~short);
end
% 4: candidates in no track
for k = 1:2
    C = cands{k};
    if isempty(C), continue; end
    member = false(size(C, 1), 1);
    for j = 1:numel(tracks{k})
        trk = tracks{k}(j);
        [~, a] = ismember([C(:, 1), round(C(:, 2:3) * 100)], [double(trk.frames(:)), round(trk.uv * 100)], 'rows');
        member = member | a > 0;
    end
    iso = find(~member);
    if isempty(iso), continue; end
    t = tv.recon.detTimes(k, C(iso, 1), C(iso, 3), rec, sync);
    for m = 1:numel(iso)
        log(end+1) = struct('cam', k, 'frame', C(iso(m), 1), 'u', C(iso(m), 2), 'v', C(iso(m), 3), 't', t(m), ...
            'X', nan(1, 3), 'track', 0, 'reason', 'isolated', 'errPx', NaN); %#ok<AGROW>
    end
end
end

function [e, X, covered] = pairWith(k, trk, tq, other, to, cams, fps, opts)
% each point of trk against one track of the other camera, interpolated to its time
n = numel(trk.frames);  e = inf(n, 1);  X = nan(n, 3);  covered = false(n, 1);
[to, ord] = sort(to);  uvo = other.uv(ord, :);
if numel(to) < 2, return; end
in = find(tq > to(1) & tq < to(end));
if isempty(in), return; end
nxt = arrayfun(@(t) find(to > t, 1), tq(in));
idx = in((to(nxt) - to(nxt - 1)) <= opts.maxGapFrames / fps);   % not across a long gap
if isempty(idx), return; end
covered(idx) = true;
q = [interp1(to, uvo(:, 1), tq(idx)), interp1(to, uvo(:, 2), tq(idx))];
pk = trk.uv(idx, :);
if k == 1, P = tv.recon.triangulate(cams(1), pk, cams(2), q);
else,      P = tv.recon.triangulate(cams(1), q, cams(2), pk); end
o = 3 - k;
e(idx) = reprojErr(cams(k), P, pk) + reprojErr(cams(o), P, q);
X(idx, :) = P;
end

function m = medFinite(x)
x = x(isfinite(x));
if numel(x) < 5, m = Inf; else, m = median(x); end
end

function e = reprojErr(cam, P, px)
[q, ok] = tv.camera.project(cam, P);
e = sqrt(sum((q - px).^2, 2));
e(~ok) = Inf;
end

function log = emptyLog()
log = struct('cam', {}, 'frame', {}, 'u', {}, 'v', {}, 't', {}, 'X', {}, 'track', {}, 'reason', {}, 'errPx', {});
end

function log = addRows(log, k, trk, t, I, rows, reason)
for m = rows(:)'
    r = reason;  if isempty(r), r = I.status{m}; end
    log(end+1) = struct('cam', k, 'frame', double(trk.frames(m)), 'u', trk.uv(m, 1), 'v', trk.uv(m, 2), 't', t(m), ...
        'X', I.X(m, :), 'track', trk.id, 'reason', r, 'errPx', I.err(m)); %#ok<AGROW>
end
end
