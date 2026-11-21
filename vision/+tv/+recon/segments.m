function [segs, dropped] = segments(P, cams, rec, sync, air, prior, opts)
%SEGMENTS  Split one rally's ball detections into flight segments and fit each (TV-REC-01, TV-TRK-02).
%   P: track pieces from both cameras (tv.recon.pieces). Every piece start,
%   end and cut, in either camera, is a possible event (hit, bounce, net,
%   or just a gap in one camera's track). The time between neighbouring
%   possible events is fitted with the flight model; then neighbours are
%   merged back whenever one flight explains both (a gap was not an event).
%   Returns segments sorted in time (struct array from tv.recon.fitSegment), and the
%   parts dropped as no physical flight ("implausible flight", TV-ADJ-04, logged).
%   Stretches only one camera saw (Chris, 18 Nov; opts.oneCam): the steps above need both
%   cameras, so such a stretch is left out by them. Afterwards each one is joined to the
%   flight before or after it when that flight explains it; otherwise, with enough
%   detections, it is fitted as a flight of its own from the one camera's sight
%   lines and the physics, pinned to where the neighbouring flights end or begin (on the
%   ground at a bounce). Such a flight has oneCam = true: its place along the sight lines
%   hangs on the pins, so treat its speed and bounce with more caution.
%   RETUNE(real footage): opts.clusterMs, opts.edgeMs, opts.minPerCam, the
%   merge test, its 3 px cap and the 5 px junk limit; opts.oneMin (6 detections, pinned at
%   both ends), opts.oneMinLoose (15, pinned at one end), opts.oneJoinS (the longest gap to a
%   neighbour that still pins, 0.08 s), opts.oneRms (1.5 px) and opts.oneJumpMps (the change
%   of velocity that makes a real event between a one-camera flight and its neighbour, 4 m/s).
if nargin < 7, opts = struct(); end
d = struct('clusterMs', 25, 'edgeMs', 4, 'minPerCam', 4, 'mergeRms', 1.5, 'splitRms', 0.6, 'splitGain', 0.6, ...
           'mergeCapPx', 3, 'junkPx', 5, 'oneCam', true, 'oneMin', 6, 'oneMinLoose', 15, 'oneJoinS', 0.08, 'oneRms', 1.5, 'oneJumpMps', 4);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
segs = [];  dropped = [];
if isempty(P), return; end
obs = vertcat(P.obs);
t = zeros(size(obs, 1), 1);
for k = 1:2
    i = obs(:, 1) == k;
    if any(i), t(i) = tv.recon.detTimes(k, obs(i, 2), obs(i, 4), rec, sync); end
end
% possible events: piece edges, clustered
e = sort([P.tStart, P.tEnd]);
E = e(1);
for k = 2:numel(e)
    if e(k) - E(end) > opts.clusterMs / 1000, E(end+1) = e(k); else, E(end) = (E(end) + e(k)) / 2; end %#ok<AGROW>
end
E = [min(t) - 1e-3, E(2:end-1), max(t) + 1e-3];
E = unique(E);
% fit each window
for w = 1:numel(E) - 1
    in = t > E(w) + opts.edgeMs / 1000 & t < E(w + 1) - opts.edgeMs / 1000;
    if numel(E) == 2, in = true(size(t)); end
    o = obs(in, :);
    if nnz(o(:, 1) == 1) < opts.minPerCam || nnz(o(:, 1) == 2) < opts.minPerCam, continue; end
    s = tv.recon.fitSegment(o, cams, rec, sync, air, prior);
    if s.ok, segs = [segs; s]; end %#ok<AGROW>
end
% split flights that hide an event, then merge neighbours one flight explains
% (what still fits worse than opts.junkPx after splitting is not one ball's flight but a stray
% track: it is dropped BEFORE merging, so the flight on either side of it can rejoin)
[segs, cuts] = refineSplits(segs, cams, rec, sync, air, prior, opts);
[segs, dj] = dropJunk(segs, cams, rec, sync, air, prior, opts);  dropped = [dropped; dj]; %#ok<AGROW>
segs = mergeAll(segs, cuts, cams, rec, sync, air, prior, opts);
% a merge can join a short piece across a real event; look again, then merge what is left
[segs, cuts2] = refineSplits(segs, cams, rec, sync, air, prior, opts);
[segs, dj] = dropJunk(segs, cams, rec, sync, air, prior, opts);  dropped = [dropped; dj]; %#ok<AGROW>
segs = mergeAll(segs, [cuts, cuts2], cams, rec, sync, air, prior, opts);
if opts.oneCam, segs = oneCamera(segs, dropped, P, cams, rec, sync, air, prior, opts); end
end

function segs = oneCamera(segs, dropped, P, cams, rec, sync, air, prior, opts)
% Detections no flight uses, in stretches where the other camera saw (almost) nothing.
used = zeros(0, 2);
for g = [segs(:); dropped(:)]', used = [used; g.obs(:, 1:2)]; end %#ok<AGROW>
runs = struct('obs', {}, 't', {});
for p = P(:)'
    free = ~ismember(p.obs(:, 1:2), used, 'rows');
    e = diff([0; free(:); 0]);  a = find(e == 1);  b = find(e == -1) - 1;
    for i = 1:numel(a)
        idx = a(i):b(i);
        if numel(idx) < 2, continue; end
        tr = [min(p.t(idx)), max(p.t(idx))];
        obsO = zeros(0, 4);  tO = zeros(0, 1);
        for q = P(:)'
            if q.cam == p.cam, continue; end
            in = q.t >= tr(1) & q.t <= tr(2);
            obsO = [obsO; q.obs(in, :)];  tO = [tO; q.t(in)]; %#ok<AGROW>
        end
        if numel(tO) >= opts.minPerCam, continue; end       % both cameras saw it: the usual steps' business
        keep = ~ismember(obsO(:, 1:2), used, 'rows');
        runs(end+1) = struct('obs', [p.obs(idx, :); obsO(keep, :)], 't', [p.t(idx); tO(keep)]); %#ok<AGROW>
    end
end
if isempty(runs), return; end
[~, o] = sort(arrayfun(@(r) min(r.t), runs));
c = tv.court.constants();
for r = runs(o)
    nr = size(r.obs, 1);  ta = min(r.t);  tb = max(r.t);
    t1 = arrayfun(@(g) min(g.t), segs);  t2 = arrayfun(@(g) max(g.t), segs);
    iIn = find(t1 < ta & t2 > tb, 1);
    iPrev = find(t2 <= ta, 1, 'last');  iNext = find(t1 >= tb, 1);
    % (1) part of a flight already found: the flight it lies inside, or the one before or after
    joined = false;
    for j = [iIn(:); iPrev(:); iNext(:)]'                % (empties of any shape: no flight yet)
        g = segs(j);
        m = tv.recon.fitSegment([g.obs; r.obs], cams, rec, sync, air, withPins(prior, g), g.x);
        if m.ok && m.rmsPx < min(max(opts.mergeRms, 1.3 * g.rmsPx), opts.mergeCapPx) && ...
                sqrt(mean(m.res(end - nr + 1:end).^2)) < opts.mergeCapPx
            segs(j) = m;  joined = true;  break
        end
    end
    if joined || nr < opts.oneMin || ~isempty(iIn), continue; end
    % (2) a flight of its own, pinned to its neighbours
    A = zeros(0, 5);
    if ~isempty(iPrev) && ta - t2(iPrev) <= opts.oneJoinS, A = [A; pinAfter(segs(iPrev), ta, air, c)]; end %#ok<AGROW>
    if ~isempty(iNext) && t1(iNext) - tb <= opts.oneJoinS, A = [A; pinBefore(segs(iNext), tb, air, c)]; end %#ok<AGROW>
    % pinned at both ends, or long enough to stand on one pin: a stub of a few detections hanging
    % off a rally's end (the ball running on into the back fence, seen by one camera) is no flight
    % to build an event on (it gave pipelineTest a phantom hit, 19 Nov)
    if isempty(A) || (size(A, 1) < 2 && nr < opts.oneMinLoose), continue; end
    pr = prior;  pr.anchors = A;
    f = tv.recon.fitSegment(r.obs, cams, rec, sync, air, pr);
    if ~f.ok || f.rmsPx > opts.oneRms, continue; end
    Pf = tv.recon.segmentModel(f.x, f.t0, [linspace(ta, tb, 20)'; A(:, 1)], air);
    off = sqrt(sum((Pf(21:end, :) - A(:, 2:4)).^2, 2)) ./ A(:, 5);
    if any(off > 3) || min(Pf(1:20, 3)) < -0.05 || max(Pf(1:20, 3)) > 15 || any(abs(Pf(1:20, 1)) > 30) || any(abs(Pf(1:20, 2)) > 20)
        continue                                    % misses a pin, or no place a ball can be
    end
    % a flight of its own only between real events: where it meets a neighbour the ball's
    % velocity must change (a bounce or a hit). If it carries on at the neighbour's velocity it
    % is that neighbour's flight, which the join above refused for a reason (the blurred first
    % frames after a hit, seen by one camera): adding it would put an event where there is
    % none (a phantom hit 90 ms after a real one in pipelineTest, 19 Nov)
    same = false;
    if ~isempty(iPrev) && ta - t2(iPrev) <= opts.oneJoinS
        [~, Vn] = tv.recon.segmentModel(segs(iPrev).x, segs(iPrev).t0, t2(iPrev), air);
        [~, Vf] = tv.recon.segmentModel(f.x, f.t0, ta, air);
        same = same || norm(Vn - Vf) < opts.oneJumpMps;
    end
    if ~isempty(iNext) && t1(iNext) - tb <= opts.oneJoinS
        [~, Vn] = tv.recon.segmentModel(segs(iNext).x, segs(iNext).t0, t1(iNext), air);
        [~, Vf] = tv.recon.segmentModel(f.x, f.t0, tb, air);
        same = same || norm(Vn - Vf) < opts.oneJumpMps;
    end
    if same, continue; end
    segs = [segs; f]; %#ok<AGROW>
    [~, s] = sort(arrayfun(@(g) min(g.t), segs));  segs = segs(s);
end
end

function pr = withPins(prior, g)
pr = prior;
if isfield(g, 'anchors') && ~isempty(g.anchors), pr.anchors = g.anchors; end
end

function a = pinAfter(g, ta, air, c)
% Where flight g, run on past its last detection, hands over to a flight starting at ta:
% on the ground if it comes down before then (a bounce), else midway (a hit), known only
% as well as the gap is short.
te = max(g.t);
tt = (te - 0.01:0.0005:max(ta, te) + 0.0005)';
[Pg, Vg] = tv.recon.segmentModel(g.x, g.t0, tt, air);
i = find(Pg(:, 3) < c.ballRadius, 1);
if ~isempty(i) && i > 1
    f = (Pg(i-1, 3) - c.ballRadius) / (Pg(i-1, 3) - Pg(i, 3));
    a = [tt(i-1) + f * 0.0005, Pg(i-1, 1:2) + f * (Pg(i, 1:2) - Pg(i-1, 1:2)), c.ballRadius, 0.03];
else
    [~, k] = min(abs(tt - (te + ta) / 2));
    a = [tt(k), Pg(k, :), 0.03 + 0.5 * max(ta - te, 0) * norm(Vg(k, :))];
end
end

function a = pinBefore(h, tb, air, c)
% The same from the other side: flight h run back before its first detection to tb.
[p0, v0] = tv.recon.segmentModel(h.x, h.t0, h.t0, air);
ts = min(h.t);
back = @(t) p0 + (t - h.t0) .* v0 + 0.5 * (t - h.t0).^2 .* [0 0 -air.g];
tt = (ts + 0.01:-0.0005:min(tb, ts) - 0.0005)';
Ph = back(tt);
i = find(Ph(:, 3) < c.ballRadius, 1);
if ~isempty(i) && i > 1 && v0(3) > 0
    f = (Ph(i-1, 3) - c.ballRadius) / (Ph(i-1, 3) - Ph(i, 3));
    a = [tt(i-1) - f * 0.0005, Ph(i-1, 1:2) + f * (Ph(i, 1:2) - Ph(i-1, 1:2)), c.ballRadius, 0.03];
else
    tm = (ts + tb) / 2;
    a = [tm, back(tm), 0.03 + 0.5 * max(ts - tb, 0) * norm(v0)];
end
end

function [segs, dropped] = dropJunk(segs, cams, rec, sync, air, prior, opts)
% A part fitting worse than opts.junkPx is dropped, unless it joins a neighbour into one
% flight within opts.mergeCapPx: a short piece with a few strays in it carries good
% detections too (16 Nov: the first 90 ms after a hit were lost, and with them the speed
% at contact). A stray track (tens of pixels) never joins.
dropped = segs([]);
k = 1;
while k <= numel(segs)
    if segs(k).rmsPx <= opts.junkPx, k = k + 1; continue; end
    joined = false;
    for j = [k + 1, k - 1]
        if j < 1 || j > numel(segs) || segs(j).rmsPx > opts.junkPx, continue; end
        m = tv.recon.fitSegment([segs(k).obs; segs(j).obs], cams, rec, sync, air, prior, segs(min(j, k)).x);
        if m.ok && m.rmsPx < opts.mergeCapPx
            segs(min(j, k)) = m;  segs(max(j, k)) = [];  joined = true;  break
        end
    end
    if ~joined, dropped(end+1, 1) = segs(k); segs(k) = []; end %#ok<AGROW>
    if joined, k = max(1, min(j, k)); end
end
end
function [segs, cuts] = refineSplits(segs, cams, rec, sync, air, prior, opts)
% A flight that fits clearly worse than a clean one usually hides an event
% (a late cut, a net cord, the drop after the net): try splitting it at
% 15 moments where both halves keep enough detections, then at the frames
% next to the best one; keep the split when both halves together fit much
% better (opts.splitGain of the error or less), then look again.
segs = segs(:);  k = 1;  cuts = [];
while k <= numel(segs)
    g = segs(k);
    if (isfinite(g.rmsPx) && g.rmsPx <= opts.splitRms) || size(g.obs, 1) < 4 * opts.minPerCam, k = k + 1; continue; end
    ts = sort(g.t);
    cams1 = g.obs(:, 1);  [~, o] = sort(g.t);  c1 = cumsum(cams1(o) == 1);  c2 = cumsum(cams1(o) == 2);
    okCut = c1 >= opts.minPerCam & c2 >= opts.minPerCam & ...
            c1(end) - c1 >= opts.minPerCam & c2(end) - c2 >= opts.minPerCam;
    if ~any(okCut), k = k + 1; continue; end
    lo = ts(find(okCut, 1));  hi = ts(find(okCut, 1, 'last'));
    best = [];  bestRms = g.rmsPx * opts.splitGain;  bestCut = NaN;
    if ~isfinite(bestRms), bestRms = Inf; end
    % coarse: 15 moments over the range where both halves have enough detections
    for c = linspace(lo, hi, 15)
        [best, bestRms, bestCut] = tryCut(g, c, best, bestRms, bestCut, cams, rec, sync, air, prior, opts);
    end
    % fine: the frames next to the best moment
    if ~isnan(bestCut)
        u = unique(ts);  [~, j] = min(abs(u - bestCut));
        for jj = max(1, j - 4):min(numel(u) - 1, j + 4)
            c = (u(jj) + u(jj + 1)) / 2;
            if c >= lo && c <= hi
                [best, bestRms, bestCut] = tryCut(g, c, best, bestRms, bestCut, cams, rec, sync, air, prior, opts);
            end
        end
    end
    % (a column throughout: the two halves go in where the flight was)
    if isempty(best), k = k + 1; else, segs = [segs(1:k-1); best(:); segs(k+1:end)]; cuts(end+1) = bestCut; end %#ok<AGROW>
end
end

function [best, bestRms, bestCut] = tryCut(g, c, best, bestRms, bestCut, cams, rec, sync, air, prior, opts)
a = g.t < c - opts.edgeMs / 1000;  b = g.t > c + opts.edgeMs / 1000;
oa = g.obs(a, :);  ob = g.obs(b, :);
if nnz(oa(:, 1) == 1) < opts.minPerCam || nnz(oa(:, 1) == 2) < opts.minPerCam || ...
   nnz(ob(:, 1) == 1) < opts.minPerCam || nnz(ob(:, 1) == 2) < opts.minPerCam, return; end
sa = tv.recon.fitSegment(oa, cams, rec, sync, air, prior);
sb = tv.recon.fitSegment(ob, cams, rec, sync, air, prior);
if ~sa.ok || ~sb.ok, return; end
r = sqrt((sa.rmsPx^2 * nnz(a) + sb.rmsPx^2 * nnz(b)) / (nnz(a) + nnz(b)));
if r < bestRms, bestRms = r; best = [sa; sb]; bestCut = c; end
end

function segs = mergeAll(segs, cuts, cams, rec, sync, air, prior, opts)
% merge neighbours one flight explains (a gap was not an event), never across a split's cut
merged = true;
while merged && numel(segs) > 1
    merged = false;
    for k = 1:numel(segs) - 1
        a = segs(k);  b = segs(k + 1);
        o = [a.obs; b.obs];
        % a split refineSplits made is never merged back
        if any(cuts > max(a.t) & cuts < min(b.t)), continue; end
        m = tv.recon.fitSegment(o, cams, rec, sync, air, prior, a.x);
        % never above opts.mergeCapPx: a junk fragment's large error must not license a junk merge
        if m.ok && m.rmsPx < min(max(opts.mergeRms, 1.3 * max(a.rmsPx, b.rmsPx)), opts.mergeCapPx)
            m.x = shiftStart(m, a);
            segs = [segs(1:k-1); m; segs(k+2:end)];
            merged = true;
            break
        end
    end
end
end

function x = shiftStart(m, a)
% fitSegment re-anchors at the earliest detection; nothing to shift
x = m.x;
end
