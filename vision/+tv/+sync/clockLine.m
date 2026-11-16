function [sync, report] = clockLine(tracks, cams, rec, sync, opts)
%CLOCKLINE  Camera 2's clock offset AND drift from the sight lines, window by window (TV-SYNC-02).
%   tracks: rallies x 2 cell of 2D ball tracks (as tv.pipeline.run's D.tracks).
%   The session is cut into windows of opts.windowMin minutes (default 10).
%   Each window's offset is found by tv.sync.fromRays, searching +/- opts.searchMs
%   (default 30) around the line from the windows before it, so a drift of tens
%   of ppm (about 2.4 ms a minute at 40 ppm) is followed through a 2-hour
%   session. The first window searches +/- 60 ms around sync.delta. A straight
%   line through the window offsets, about sync.tref, gives Delta and epsilon.
%   With one usable window only the offset is set and the drift stays as given.
%   The fine fit (tv.recon.refineSession) then refines both.
%   Found 16 Nov: one offset for a 90-minute session left the ends 70-100 ms out
%   at 40 ppm, and most shots were lost (fit study).
%   RETUNE(real footage): windowMin, searchMs.
if nargin < 5, opts = struct(); end
d = struct('windowMin', 10, 'searchMs', 30, 'firstSearchMs', 60);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
nR = size(tracks, 1);
s0 = sync;  s0.delta = 0;  s0.drift = 0;
tMid = nan(nR, 1);
for r = 1:nR
    P = tv.recon.pieces(tracks(r, :), rec, s0);
    if ~isempty(P), tMid(r) = median(vertcat(P([P.cam] == 1).t)); end
end
ok = isfinite(tMid);
report = struct('t', [], 'delta', [], 'gap', []);
if ~any(ok), return; end
w = floor((tMid - min(tMid(ok))) / (60 * opts.windowMin));
for k = unique(w(ok))'
    in = ok & w == k;
    all1 = [tracks{in, 1}];  all2 = [tracks{in, 2}];
    tk = median(tMid(in));
    if isempty(report.t)
        c = sync.delta;  span = opts.firstSearchMs;
    elseif numel(report.t) == 1
        c = report.delta(end);  span = opts.searchMs;
    else
        p = polyfit(report.t, report.delta, 1);  c = polyval(p, tk);  span = opts.searchMs;
    end
    [dk, curve] = tv.sync.fromRays({all1, all2}, cams, rec, s0, span, c);
    if all(isnan(curve)), continue; end
    report.t(end+1) = tk;  report.delta(end+1) = dk;  report.gap(end+1) = min(curve);
end
if numel(report.t) >= 2 && max(report.t) > min(report.t)
    p = polyfit(report.t - sync.tref, report.delta, 1);
    sync.drift = p(1);  sync.delta = p(2);
elseif numel(report.t) == 1
    sync.delta = report.delta;
end
end
