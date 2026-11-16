function [tracks, info, log] = keepCourt(tracks, info, box, opts)
%KEEPCOURT  Only the two players on Chris's court (TV-ADJ-05).
%   tracks/info from tv.players.track (feet placed on the court plane, TV-PLY-01).
%   A person track is on court when at least opts.playerInsideFrac of its
%   samples have the feet inside the court-of-interest footprint. Of those,
%   never more than two at the same moment: where a third overlaps in time,
%   the one with the fewest inside samples goes ("third person on court").
%   Fragments of the same player that follow each other in time are kept.
%   Everyone else is dropped ("person off court"), so hits can only be
%   credited to Chris and his opponent (TV-PLY-09). info.chris and
%   info.confidence follow the kept tracks.
%   log: struct array: track, tStart, tEnd, x, y (median feet), insideFrac, reason.
%   RETUNE(real footage): opts.playerInsideFrac.
if nargin < 4, opts = struct(); end
if ~isfield(opts, 'playerInsideFrac'), opts.playerInsideFrac = 0.6; end
log = struct('track', {}, 'tStart', {}, 'tEnd', {}, 'x', {}, 'y', {}, 'insideFrac', {}, 'reason', {});
n = numel(tracks);
if n == 0, return; end
inside = zeros(1, n);  frac = zeros(1, n);
for k = 1:n
    in = tv.court.inInterest(tracks(k).xy, box);
    inside(k) = nnz(in);  frac(k) = mean(in);
end
keep = frac >= opts.playerInsideFrac;
reason = repmat({''}, 1, n);
reason(~keep) = {'person off court'};
% at most two at once: drop the weakest of any three that overlap
[~, order] = sort(inside, 'descend');
chosen = [];
for k = order
    if ~keep(k), continue; end
    t0 = tracks(k).t(1);  t1 = tracks(k).t(end);
    overl = arrayfun(@(j) tracks(j).t(1) < t1 && tracks(j).t(end) > t0, chosen);
    if nnz(overl) >= 2
        keep(k) = false;  reason{k} = 'third person on court';
    else
        chosen(end+1) = k; %#ok<AGROW>
    end
end
for k = find(~keep)
    log(end+1) = struct('track', k, 'tStart', tracks(k).t(1), 'tEnd', tracks(k).t(end), ...
        'x', median(tracks(k).xy(:, 1)), 'y', median(tracks(k).xy(:, 2)), 'insideFrac', frac(k), 'reason', reason{k}); %#ok<AGROW>
end
idx = find(keep);
tracks = tracks(idx);
c = find(idx == info.chris, 1);
if isempty(c), c = 0; end
info.chris = c;
info.confidence = info.confidence(idx);
end
