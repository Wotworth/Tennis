function segs = segments(P, cams, rec, sync, air, prior, opts)
%SEGMENTS  Split one rally's ball detections into flight segments and fit each (TV-REC-01, TV-TRK-02).
%   P: track pieces from both cameras (tv.recon.pieces). Every piece start,
%   end and cut, in either camera, is a possible event (hit, bounce, net,
%   or just a gap in one camera's track). The time between neighbouring
%   possible events is fitted with the flight model; then neighbours are
%   merged back whenever one flight explains both (a gap was not an event).
%   Returns segments sorted in time (struct array from tv.recon.fitSegment).
%   RETUNE(real footage): opts.clusterMs, opts.edgeMs, opts.minPerCam, the
%   merge test, its 3 px cap and the 5 px junk limit.
if nargin < 7, opts = struct(); end
d = struct('clusterMs', 25, 'edgeMs', 4, 'minPerCam', 4, 'mergeRms', 1.5, 'splitRms', 0.6, 'splitGain', 0.6, ...
           'mergeCapPx', 3, 'junkPx', 5);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
segs = [];
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
segs = dropJunk(segs, opts);
segs = mergeAll(segs, cuts, cams, rec, sync, air, prior, opts);
% a merge can join a short piece across a real event; look again, then merge what is left
[segs, cuts2] = refineSplits(segs, cams, rec, sync, air, prior, opts);
segs = dropJunk(segs, opts);
segs = mergeAll(segs, [cuts, cuts2], cams, rec, sync, air, prior, opts);
end

function segs = dropJunk(segs, opts)
if ~isempty(segs), segs = segs([segs.rmsPx] <= opts.junkPx); end
end
function [segs, cuts] = refineSplits(segs, cams, rec, sync, air, prior, opts)
% A flight that fits clearly worse than a clean one usually hides an event
% (a late cut, a net cord, the drop after the net): try splitting it at
% 15 moments where both halves keep enough detections, then at the frames
% next to the best one; keep the split when both halves together fit much
% better (opts.splitGain of the error or less), then look again.
k = 1;  cuts = [];
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
    if isempty(best), k = k + 1; else, segs = [segs(1:k-1); best; segs(k+1:end)]; cuts(end+1) = bestCut; end %#ok<AGROW>
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
