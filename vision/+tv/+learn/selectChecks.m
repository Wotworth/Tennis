function pick = selectChecks(cands, n, opts)
%SELECTCHECKS  Which frames to ask Chris about in "Ball check" (Chris, 15 Nov).
%   cands: struct array of possible frames, one per (session, camera,
%   frame), with fields sessionId, cam, frame, xy (the detector's ball,
%   NaN if none), day (session date number), light (mean brightness 0-1)
%   and unsure (0-1: how unsure the pipeline was: low detector score, a
%   detection off the fitted flight, or a flight with no detection).
%   Picks n frames: about two thirds of them the most unsure, the rest
%   spread evenly across days and light levels, so the test set covers
%   new courts, indoor and night as conditions change. Frames already in
%   the test set (opts.exclude keys) are skipped.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'exclude'), opts.exclude = {}; end
keys = arrayfun(@(c) sprintf('%s|%s', c.sessionId, tv.learn.frameRef(c.cam, c.frame)), cands, 'UniformOutput', false);
ok = ~ismember(keys, opts.exclude);
cands = cands(ok);
pick = cands([]);
if isempty(cands), return; end
nUnsure = min(numel(cands), round(n * 2 / 3));
[~, o] = sort([cands.unsure], 'descend');
pick = cands(o(1:nUnsure));
rest = cands(o(nUnsure + 1:end));
% spread: bin by day and by light (quartiles), then take round-robin
if ~isempty(rest) && numel(pick) < n
    lightBin = min(4, 1 + floor(4 * [rest.light]));
    [~, ~, groups] = unique([[rest.day]', lightBin'], 'rows');
    g = unique(groups);  k = 1;
    queues = arrayfun(@(x) find(groups == x), g, 'UniformOutput', false);
    while numel(pick) < n && any(~cellfun(@isempty, queues))
        q = queues{k};
        if ~isempty(q), pick(end+1) = rest(q(1)); queues{k} = q(2:end); end %#ok<AGROW>
        k = mod(k, numel(queues)) + 1;
    end
end
end
