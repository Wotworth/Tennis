function [summary, data] = payload(R, mode)
%PAYLOAD  What the cloud gets for a session: a summary and the rows (TV-UP-01, TV-API-02).
%   Only the PC's measurements. No court names, no photos, no health data.
if nargin < 2, mode = 'full'; end
summary = struct('startUtc', R.rec(1).startUtc, 'mode', mode);
sh = R.shots;
chris = [];  serves = [];                             % no shots (an empty-court clip): 22 Nov
if isstruct(sh) && ~isempty(sh), chris = sh(strcmp({sh.hitter}, 'Chris')); end
if ~isempty(chris), serves = chris([chris.isServe]); end
head = sprintf('%d shots', numel(chris));
if ~isempty(serves), head = sprintf('%s, fastest serve %d mph', head, round(max([serves.speedContact]) * 2.237)); end
dur = 0;  if ~isempty(R.rallies), dur = max([R.rallies.stop]) - min([R.rallies.start]); end
stats = struct('shotType', {}, 'metric', {}, 'median', {}, 'iqr', {}, 'n', {});
types = fieldnames(R.summary.byType);
for i = 1:numel(types)
    t = R.summary.byType.(types{i});
    for m = {'speed', 'spinEffect', 'rpm', 'netClearance', 'depth'}
        v = t.(m{1});
        stats(end+1) = struct('shotType', types{i}, 'metric', m{1}, 'median', v.median, 'iqr', v.iqr, 'n', v.n); %#ok<AGROW>
    end
    stats(end+1) = struct('shotType', types{i}, 'metric', 'inPct', 'median', t.inPct, 'iqr', 0, 'n', t.count); %#ok<AGROW>
    stats(end+1) = struct('shotType', types{i}, 'metric', 'ellipseArea', 'median', t.ellipseArea, 'iqr', 0, 'n', t.count); %#ok<AGROW>
end
cd = NaN;  if isfield(R.air, 'sessionCD'), cd = R.air.sessionCD; end
stats(end+1) = struct('shotType', 'all', 'metric', 'sessionCD', 'median', cd, 'iqr', 0, 'n', numel(sh));
data = struct('session', struct('durationS', dur, 'headline', head, 'identityPending', R.players.question), ...
    'rallies', R.rallies, 'shots', sh, 'stats', stats, 'complete', true);
end
