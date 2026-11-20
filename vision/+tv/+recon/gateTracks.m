function [kept, log, partners] = gateTracks(tracks, cands, cams, rec, sync, box, opts)
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
%      other camera worse there gives up those points ("overlaps a better track"), but only
%      when the two are the same ball: their 3D points over the overlap are within
%      opts.sameBallM (median). Two balls in view at once are both kept.
%   0. A track whose points switch from one of the other camera's tracks to another, with a jump
%      in 3D, is cut there first: a 2D tracker that ran on along the other ball (21 Nov).
%   1b. A point paired with another track than its partner (where the partner has a gap) is kept
%      only if it lies on the track's own path; otherwise "paired with another ball" (21 Nov).
%   4. Candidates that are in no track are logged "isolated".
%   The flight fit (tv.recon.segments) then drops what no physical flight
%   explains ("implausible flight", logged by the pipeline).
%
%   kept: 1-by-2 cell of the kept tracks (points removed as above).
%   partners: 1-by-2 cell; for each kept track, the id of its stereo partner track in the
%   other camera (0 if none), so two balls in view at once are fitted apart (tv.recon.ballGroups).
%   log: struct array, one row per rejected candidate: cam, frame, u, v, t,
%   X (1-by-3, NaN if never triangulated), track (that camera's track id, 0 if
%   none), reason, errPx.
%   RETUNE(real footage): every opts value (tv.pipeline.defaults, cfg.gate).
if nargin < 7, opts = struct(); end
d = struct('epipolarPx', 4, 'minInsideFrac', 0.5, 'minPairedFrac', 0.3, 'maxSpeed', 75, 'maxGapFrames', 3, 'sameBallM', 2, 'rollMaxZ', 0.3, 'rollMinS', 0.3, 'rollShare', 0.9, ...
    'otherPairM', 0.5, 'otherPairS', 0.25, 'splitRun', 8, 'splitJumpM', 1.5);
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
% 0 (21 Nov, Chris: why does tracking ever take the other ball?): a camera's 2D tracker links by
% motion alone, so where two balls pass close in its picture a track can run on along the other
% ball (CI run 56: camera 2 followed the neighbours' ball through Chris's serve, and the track,
% mostly the neighbours', was dropped whole with his serve in it). The other camera shows the
% switch: the track's points start pairing with a different track there, and the 3D point jumps.
% Such a track is cut at the switch, and each piece is judged on its own.
[tracks, T] = splitAtSwitches(tracks, T, cams, rec, sync, opts);
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
        best = inf(n, 1);  X = nan(n, 3);  pid = 0;
        if ~isempty(E)
            med = arrayfun(@(jj) medFinite(E(:, jj)), 1:size(E, 2));
            [mp, partner] = min(med);
            [emin, imin] = min(E, [], 2);
            usePartner = isfinite(mp) & mp <= opts.epipolarPx & E(:, partner) <= opts.epipolarPx;
            if isfinite(mp) && mp <= opts.epipolarPx, pid = tracks{o}(partner).id; end
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
        % 21 Nov (Chris: why does pairing ever take the other ball?): a point paired with some other
        % track than its own partner lands wherever that other ball's sight line meets its own, and
        % any pixel on the other camera's epipolar line passes the epipolar test. Where the track's
        % own partner had a gap, the stray in adjacentTest paired with Chris's ball this way and got
        % points 0.7 to 1.4 m up. Such a point is kept only if it lies on the track's own path (from
        % its partner-paired points); otherwise it is dropped as "paired with another ball".
        if pid > 0
            other = paired & ~out & ~usePartner;
            if any(other), st(other & ~onOwnPath(T{k}{j}, X, usePartner & paired, other, opts)) = {'paired with another ball'}; end
        end
        info{k}{j} = struct('status', {st}, 'X', X, 'err', best, 'partner', pid);
    end
end
% 3: track decisions
keptErr = {{}, {}};  keptT = {{}, {}};  keptX = {{}, {}};  partners = {zeros(1, 0), zeros(1, 0)};
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
        % a ball rolling on the ground (a stray from the next court, or a dead ball) is not a
        % shot: all its 3D points low for at least opts.rollMinS (CI 17 Nov: a stray rolling
        % across Chris's court was accepted once flights were fitted per ball)
        % 20 Nov: "low" is judged on the 90th percentile of its heights, not the highest point: with
        % the learned detector the stray in adjacentTest's second rally had 90% of its points under
        % 5 cm but a few mis-paired ones at 0.7 to 1.4 m, so it was kept, fitted together with
        % Chris's ball, and the whole stretch (two of his shots) was dropped
        if isempty(reason) && nnz(inside) >= 5
            zi = sort(I.X(inside, 3));  ti = t(inside);
            if zi(ceil(opts.rollShare * numel(zi))) < opts.rollMaxZ && max(ti) - min(ti) >= opts.rollMinS
                reason = 'rolling on the ground';
            end
        end
        if ~isempty(reason)
            log = addRows(log, k, trk, t, I, 1:numel(t), reason);
            continue
        end
        % implausible jumps between neighbouring inside points (time order)
        drop = (~inside & paired) | strcmp(I.status, 'paired with another ball');   % outside points; other balls' pairs
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
            keptX{k}{end+1} = I.X(~drop, :); %#ok<AGROW>
            partners{k}(end+1) = I.partner; %#ok<AGROW>
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
                % only two tracks of the same ball: over the overlap their 3D points lie
                % within opts.sameBallM (two balls in view at once both stay; 17 Nov, AC-15)
                if ~sameBall(ta(ia), keptX{k}{a}(ia, :), tb(ib), keptX{k}{b}(ib, :), opts.sameBallM), continue; end
                ea = median(min(keptErr{k}{a}(ia), 1e3));  eb = median(min(keptErr{k}{b}(ib), 1e3));
                if ea <= eb, lose = b; m = ib; else, lose = a; m = ia; end
                if ~any(m), continue; end
                trk = kept{k}(lose);  I = struct('status', {repmat({'overlaps a better track'}, numel(m), 1)}, ...
                    'X', nan(numel(m), 3), 'err', keptErr{k}{lose});
                log = addRows(log, k, trk, keptT{k}{lose}, I, find(m), '');
                trk.frames = trk.frames(~m);  trk.uv = trk.uv(~m, :);  trk.area = trk.area(~m);
                kept{k}(lose) = trk;  keptErr{k}{lose} = keptErr{k}{lose}(~m);  keptT{k}{lose} = keptT{k}{lose}(~m);  keptX{k}{lose} = keptX{k}{lose}(~m, :);
                changed = true;  break
            end
            if changed, break; end
        end
    end
    short = arrayfun(@(x) numel(x.frames) < 3, kept{k});
    kept{k} = kept{k}(~short);  partners{k} = partners{k}(~short);
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

function [tracks, T] = splitAtSwitches(tracks, T, cams, rec, sync, opts)
% cut a track where its points switch, for opts.splitRun points or more on each side, from pairing
% with one track of the other camera to pairing with another, the 3D point jumps by more than
% opts.splitJumpM, and the old partner is still in view after the switch but no longer matches.
% (One ball's track broken in two by the other camera's tracker pairs continuously and is not cut;
% a gap in the old partner is not a switch of this track.)
cuts = cell(1, 2);
for k = 1:2
    o = 3 - k;  fps = 1 / median(diff(rec(o).pts));  cuts{k} = cell(1, numel(tracks{k}));
    for j = 1:numel(tracks{k})
        trk = tracks{k}(j);  n = numel(trk.frames);
        if n < 2 * opts.splitRun || numel(tracks{o}) < 2, continue; end
        E = inf(n, numel(tracks{o}));  XX = nan(n, 3, numel(tracks{o}));
        for jj = 1:numel(tracks{o})
            [E(:, jj), XX(:, :, jj)] = pairWith(k, trk, T{k}{j}, tracks{o}(jj), T{o}{jj}, cams, fps, opts);
        end
        [em, lab] = min(E, [], 2);  lab(em > opts.epipolarPx) = 0;
        [~, ord] = sort(T{k}{j});  L = lab(ord);
        X = nan(n, 3);  for m = 1:n, if lab(m) > 0, X(m, :) = XX(m, :, lab(m)); end, end
        X = X(ord, :);
        % runs of one label among the paired points
        pi_ = find(L > 0);  if isempty(pi_), continue; end
        rs = pi_(1);  c = [];
        for q = 2:numel(pi_) + 1
            if q > numel(pi_) || L(pi_(q)) ~= L(pi_(q - 1))
                re = pi_(q - 1);
                if q <= numel(pi_)
                    nA = nnz(L(rs:re) == L(re));  nB = nnz(L(pi_(q):min(n, pi_(q) + 3 * opts.splitRun)) == L(pi_(q)));
                    jump = norm(X(pi_(q), :) - X(re, :));
                    % the old partner is still there after the switch but no longer matches: this
                    % camera's tracker jumped (a gap in the old partner is not a switch here)
                    after = ord(pi_(q):min(n, pi_(q) + opts.splitRun - 1));
                    eOld = E(after, L(re));
                    stillThere = nnz(isfinite(eOld) & eOld > opts.epipolarPx) >= 0.5 * numel(after);
                    if nA >= opts.splitRun && nB >= opts.splitRun && jump > opts.splitJumpM && stillThere
                        c(end+1) = ord(pi_(q)); %#ok<AGROW>   % the first point of the new run (original order)
                    end
                end
                if q <= numel(pi_), rs = pi_(q); end
            end
        end
        cuts{k}{j} = c;
    end
end
for k = 1:2
    if ~any(cellfun(@numel, cuts{k})), continue; end
    nextId = max([tracks{k}.id]) + 1;  out = tracks{k}([]);  To = {};
    for j = 1:numel(tracks{k})
        trk = tracks{k}(j);  t = T{k}{j};
        if isempty(cuts{k}{j}), out(end+1) = trk; To{end+1} = t; continue; end %#ok<AGROW>
        tc = sort(t(cuts{k}{j}));  edges = [-Inf; tc(:); Inf];
        for p = 1:numel(edges) - 1
            m = t >= edges(p) & t < edges(p + 1);
            if ~any(m), continue; end
            piece = sliceTrack(trk, m);
            if p > 1, piece.id = nextId;  nextId = nextId + 1; end
            out(end+1) = piece;  To{end+1} = t(m); %#ok<AGROW>
        end
    end
    tracks{k} = out;  T{k} = To;
end
end

function s = sliceTrack(trk, m)
% the points m of a track (every per-point field)
s = trk;  n = numel(m);
for f = fieldnames(trk)'
    v = trk.(f{1});
    if size(v, 1) == n && n > 1, s.(f{1}) = v(m, :); end
end
end

function ok = onOwnPath(t, X, own, other, opts)
% points paired with another track: within opts.otherPairM of the track's own path at that time
% (its partner-paired points: interpolated between the nearest on each side, or from the nearest
% one plus the local speed times the gap), judged only within opts.otherPairS of an own point;
% further away from any own point there is nothing to judge by and the pair stands
ok = true(size(t));
io = find(own);
if numel(io) < 2, return; end
[to, ord] = sort(t(io));  Xo = X(io(ord), :);
[to, u] = unique(to);  Xo = Xo(u, :);
if numel(to) < 2, return; end
v = sqrt(sum(diff(Xo) .^ 2, 2)) ./ max(diff(to), 1e-4);  vMed = median(v);
for m = find(other(:))'
    tm = t(m);
    [dt, a] = min(abs(to - tm));
    if dt > opts.otherPairS, continue; end
    if tm > to(1) && tm < to(end)
        b = find(to > tm, 1);  f = (tm - to(b - 1)) / (to(b) - to(b - 1));
        P = Xo(b - 1, :) + f * (Xo(b, :) - Xo(b - 1, :));  lim = opts.otherPairM + 0.5 * 9.81 * (to(b) - to(b - 1)) ^ 2;
    else
        P = Xo(a, :);  lim = opts.otherPairM + vMed * dt;
    end
    ok(m) = norm(X(m, :) - P) <= lim;
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

function same = sameBall(ta, Xa, tb, Xb, lim)
% median 3D distance between the two tracks' points, each b point against a's nearest in time
ga = all(isfinite(Xa), 2);  gb = all(isfinite(Xb), 2);
same = false;
if ~any(ga) || ~any(gb), return; end
ta = ta(ga);  Xa = Xa(ga, :);  tb = tb(gb);  Xb = Xb(gb, :);
[~, i] = min(abs(tb(:) - ta(:)'), [], 2);
same = median(sqrt(sum((Xb - Xa(i, :)).^2, 2))) <= lim;
end
