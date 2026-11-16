function out = missedShot(result, t, rescan)
%MISSEDSHOT  Re-examine a "Missed a shot here" window (Chris, 15 Nov).
%   t: seconds into the session where Chris says a shot was missed. The
%   window t - 1.5 s .. t + 1.5 s is detected again with looser thresholds
%   (rescan(window) returns the tracks for both cameras, by default the
%   pipeline's detector with lower colour and size limits), fitted with the
%   flight model, and any flight that fits well (RMS under 1.5 px, both
%   cameras) and is not already one of the session's flights is confirmed.
%   out.confirmed: the new flights (they become training examples, kind
%   'confirmed-missed'); out.note: one line for the flag.
w = [t - 1.5, t + 1.5];
tracks = rescan(w);
P = tv.recon.pieces(tracks, result.rec, result.sync);
segs = tv.recon.segments(P, result.cams, result.rec, result.sync, result.air, struct('CD', 0.507, 'CDsd', 0.024));
old = [];
for r = 1:numel(result.segs)
    for g = result.segs{r}(:)', old(end+1, :) = [g.t0, max(g.t)]; end %#ok<AGROW>
end
out.confirmed = [];
for g = segs(:)'
    if ~g.ok || g.rmsPx > 1.5 || any(g.n < 6), continue; end
    seen = ~isempty(old) && any(old(:, 1) < max(g.t) - 0.05 & old(:, 2) > g.t0 + 0.05);
    if ~seen, out.confirmed = [out.confirmed; g]; end %#ok<AGROW>
end
if isempty(out.confirmed)
    out.note = sprintf('looked again at %.1f-%.1f s: no flight both cameras agree on', w);
else
    out.note = sprintf('added %d flight(s) at %s s', numel(out.confirmed), mat2str(round([out.confirmed.t0] * 10) / 10));
end
end
