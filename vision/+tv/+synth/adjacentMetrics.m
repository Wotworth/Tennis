function m = adjacentMetrics(result, truth, cams, sc, limits)
%ADJACENTMETRICS  How well the pipeline kept to Chris's court (TV-ADJ-08, AC-14 to AC-16).
%   Every ball candidate is labelled by the truth: Chris's ball, another ball
%   (a neighbour's, the crossing ball, the rolling stray) or neither, by projecting
%   each truth ball into the TRUE camera at the moment that pixel row was exposed
%   (within opts.tolPx). Then:
%   falsePos   other balls' detections among the accepted ones (in the final
%              flights), as a share of all accepted (AC-14)
%   falseNeg   Chris's ball: detections that joined a 2D track but were then
%              rejected (by the gate or the flight fit), as a share of those
%              that joined a track (AC-15). Detections the detector or tracker
%              never linked are outside this test (TV-DET-06). Chris's ball where it
%              truly is outside the court of interest is rejected by design and
%              counted apart (mineOutsideBox).
%   swaps      hits credited to anyone but the true hitter, plus kept player
%              tracks that switch person, plus kept tracks that are a neighbour (AC-16)
%   pass       each against limits (cfg.adjacentTest: maxFalsePos, maxFalseNeg, maxSwaps)
%   Also: counts per label and reason, for the report.
if nargin < 5, limits = tv.pipeline.defaults().adjacentTest; end
tolPx = 4 * sc.frameSize(1) / 960;
balls = {truth.ballP};  kinds = {'mine'};
for o = truth.others.balls(:)', balls{end+1} = o.ballP; kinds{end+1} = o.kind; end %#ok<AGROW>
% --- label every candidate, and mark the ones that joined a track / were accepted
lab = {};  inTrack = [];  accepted = [];  why = {};  outsideBox = [];
box = tv.court.interest(tv.pipeline.defaults().court);
for r = 1:size(result.candidates, 1)
    acc = obsOf(result.segs{r});
    rej = result.gateLog{r};
    for k = 1:2
        C = result.candidates{r, k};
        if isempty(C), continue; end
        [L, Ptrue] = labelCands(C, k, result.rec, cams, truth, balls, kinds, tolPx);
        outsideBox = [outsideBox; ~tv.court.inInterest(Ptrue, box)]; %#ok<AGROW>
        a = ismember([k * ones(size(C, 1), 1), C(:, 1), round(C(:, 2:3) * 100)], ...
                     [acc(:, 1:2), round(acc(:, 3:4) * 100)], 'rows');
        iso = false(size(C, 1), 1);  w = repmat({''}, size(C, 1), 1);
        if ~isempty(rej)
            g = rej([rej.cam] == k);
            key = [[g.frame]', round([[g.u]', [g.v]'] * 100)];
            [hit, loc] = ismember([C(:, 1), round(C(:, 2:3) * 100)], key, 'rows');
            w(hit) = {g(loc(hit)).reason};
            iso(hit) = strcmp(w(hit), 'isolated');
        end
        lab = [lab; L]; %#ok<AGROW>
        inTrack = [inTrack; ~iso]; %#ok<AGROW>
        accepted = [accepted; a]; %#ok<AGROW>
        w(a) = {''};
        w(~a & ~iso & cellfun(@isempty, w)) = {'flight fit'};
        why = [why; w]; %#ok<AGROW>
    end
end
mine = strcmp(lab, 'mine');  other = ~mine & ~strcmp(lab, 'none');
% Chris's ball where it truly is outside the court of interest (flying on past the box after an
% out ball) is rejected by design (TV-ADJ-01); counted apart, not as a false negative (17 Nov)
outsideBox = logical(outsideBox);
m.mineOutsideBox = nnz(mine & outsideBox);
mine = mine & ~outsideBox;
accepted = logical(accepted);  inTrack = logical(inTrack);
m.accepted = nnz(accepted);
m.acceptedOther = nnz(accepted & other);
m.falsePos = m.acceptedOther / max(1, m.accepted);
m.mineInTrack = nnz(mine & inTrack);
m.mineRejected = nnz(mine & inTrack & ~accepted);
m.falseNeg = m.mineRejected / max(1, m.mineInTrack);
m.byKind = struct();
for kk = unique(lab)'
    f = matlab.lang.makeValidName(kk{1});
    s = strcmp(lab, kk{1});
    m.byKind.(f) = struct('detected', nnz(s), 'inTrack', nnz(s & inTrack), 'accepted', nnz(s & accepted));
end
r = why(mine & inTrack & ~accepted);
[u, ~, j] = unique(r);
m.mineRejectedWhy = struct('reason', {}, 'n', {});
if ~isempty(u), m.mineRejectedWhy = struct('reason', u(:)', 'n', num2cell(accumarray(j(:), 1)')); end
% --- identity swaps
rep = tv.synth.compare(result, truth, cams, sc);
m.hitSwaps = nnz(~rep.hitterOk);
people = {@(T) tv.synth.playerAt(truth, 1, T), @(T) tv.synth.playerAt(truth, 2, T)};
for o = truth.others.players(:)'
    people{end+1} = @(T) tv.synth.playerAt(struct('players', {{o.way}}), 1, T); %#ok<AGROW>
end
m.trackSwaps = 0;  m.neighbourKept = 0;
for tr = result.players.tracks(:)'
    d = zeros(numel(tr.t), numel(people));
    for p = 1:numel(people), d(:, p) = sqrt(sum((people{p}(tr.t(:)) - tr.xy).^2, 2)); end
    [~, who] = min(d, [], 2);
    runs = [who(1); who(find(diff(who)) + 1)];
    lens = diff([0; find(diff(who)); numel(who)]);
    runs = runs(lens >= 3);                                    % ignore one- or two-sample flickers
    m.trackSwaps = m.trackSwaps + max(0, numel(unique(runs)) - 1);
    if mode(who) > 2, m.neighbourKept = m.neighbourKept + 1; end
end
m.swaps = m.hitSwaps + m.trackSwaps + m.neighbourKept;
m.limits = limits;
m.pass = struct('falsePos', m.falsePos <= limits.maxFalsePos, 'falseNeg', m.falseNeg <= limits.maxFalseNeg, ...
    'swaps', m.swaps <= limits.maxSwaps);
end

function o = obsOf(segs)
o = zeros(0, 4);
for s = segs(:)', o = [o; s.obs(:, 1:4)]; end %#ok<AGROW>
end

function [L, Pbest] = labelCands(C, k, rec, cams, truth, balls, kinds, tolPx)
cam = cams(k);
clock = cam.recordStart + rec(k).pts(C(:, 1) + 1) + cam.readout * (C(:, 3) - 1) / cam.height + cam.shutter / 2;
T = tv.synth.truthTime(cam, clock);
best = inf(size(C, 1), 1);  L = repmat({'none'}, size(C, 1), 1);  Pbest = nan(size(C, 1), 3);
for b = 1:numel(balls)
    P = tv.synth.ballAt(struct('T', truth.T, 'ballP', balls{b}), T);
    [px, ok] = tv.camera.project(cam, P);
    d = sqrt(sum((px - C(:, 2:3)).^2, 2));  d(~ok | any(isnan(P), 2)) = Inf;
    take = d < best & d <= tolPx;
    best(take) = d(take);  L(take) = kinds(b);  Pbest(take, :) = P(take, :);
end
end
