function T = inPlay(T, value, minLen)
%INPLAY  One ball in play (TV-DET-04, 18 Nov): where chains overlap in time, each frame keeps only
%   the most valuable chain's point (tv.track.chains gives T and value). Another ball (a
%   neighbour's, one rolling to the fence, a spare in a pocket) can still be tracked where the
%   ball in play is not seen, never at the same moment. Chains left with fewer than minLen points
%   (default 5) are dropped.
if nargin < 3, minLen = 5; end
if isempty(T), return; end
f = vertcat(T.frames);
owner = repelem((1:numel(T))', arrayfun(@(t) numel(t.frames), T(:)));
v = value(owner);
best = containers.Map('KeyType', 'double', 'ValueType', 'double');
[~, order] = sort(v, 'descend');
for i = order(:)'
    if ~isKey(best, f(i)), best(f(i)) = owner(i); end
end
keep = true(numel(T), 1);
for r = 1:numel(T)
    k = arrayfun(@(x) best(x) == r, T(r).frames(:));
    T(r).frames = T(r).frames(k);  T(r).uv = T(r).uv(k, :);  T(r).area = T(r).area(k);  T(r).score = T(r).score(k);
    keep(r) = nnz(k) >= minLen;
end
T = T(keep);
end
