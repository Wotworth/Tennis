function G = ballGroups(tracks, partners, overlapFrames)
%BALLGROUPS  Kept tracks grouped by ball, from their stereo partners (TV-ADJ-04, 17 Nov).
%   tracks: 1-by-2 cell of each camera's kept tracks (tv.recon.gateTracks); partners: their
%   partner ids in the other camera (0 = none). Tracks linked by partnership, directly or
%   through a chain, are one group. Each group is a 1-by-2 cell of track arrays, for
%   tv.recon.pieces and tv.recon.segments, which assume one ball at a time: two balls in
%   view at once (a stray rolling across while the rally goes on) are then fitted apart.
%   Without partners (older stage files), everything is one group.
if nargin < 3, overlapFrames = 12; end    % tracks can overlap a few frames at a hit
if nargin < 2 || isempty(partners) || all(cellfun(@isempty, partners))
    G = {tracks};  return
end
n1 = numel(tracks{1});  n2 = numel(tracks{2});
lab = 1:(n1 + n2);                                   % union-find over camera 1 then camera 2 tracks
ids = {arrayfun(@(t) t.id, tracks{1}), arrayfun(@(t) t.id, tracks{2})};
for k = 1:2
    o = 3 - k;
    for j = 1:numel(tracks{k})
        m = find(ids{o} == partners{k}(j), 1);
        if partners{k}(j) == 0 || isempty(m), continue; end
        a = node(k, j);  b = node(o, m);
        ra = root(a);  rb = root(b);
        lab(ra) = rb;
    end
end
r = arrayfun(@root, 1:(n1 + n2));
u = unique(r);
G = {};
for g = u
    s1 = r(1:n1) == g;  s2 = r(n1 + 1:end) == g;
    G{end+1} = {tracks{1}(s1), tracks{2}(s2)}; %#ok<AGROW>
end
% a group seen by one camera only (its partner was dropped) joins the two-camera group
% nearest in time, as before grouping; frames stand in for time (offsets are a few frames)
both = cellfun(@(g) ~isempty(g{1}) && ~isempty(g{2}), G);
if any(both) && ~all(both)
    span = cellfun(@(g) spanOf(g), G, 'UniformOutput', false);
    for i = find(~both)
        d = inf(1, numel(G));
        for j = find(both)
            d(j) = max(0, max(span{i}(1) - span{j}(2), span{j}(1) - span{i}(2)));
        end
        [~, j] = min(d);
        for k = 1:2, G{j}{k} = [G{j}{k}(:); G{i}{k}(:)]'; end
    end
    G = G(both);
end
% chain groups that follow one another in time (the ball in play, its tracks broken at hits
% and bounces) back into one group, as before grouping: only a group that overlaps the chain
% in time (a second ball in view at once) starts another (CI 17 Nov: splitting every group
% broke two calls)
if numel(G) > 1
    span = cellfun(@(g) spanOf(g), G, 'UniformOutput', false);
    sp = vertcat(span{:});
    [~, o] = sort(sp(:, 1));
    chains = {};  chainEnd = [];
    for i = o(:)'
        c = find(chainEnd < sp(i, 1) + overlapFrames, 1);
        if isempty(c)
            chains{end+1} = G{i};  chainEnd(end+1) = sp(i, 2); %#ok<AGROW>
        else
            for k = 1:2, chains{c}{k} = [chains{c}{k}(:); G{i}{k}(:)]'; end
            chainEnd(c) = max(chainEnd(c), sp(i, 2));
        end
    end
    G = chains;
end
    function i = node(k, j)
        i = j + (k == 2) * n1;
    end
    function x = root(x)
        while lab(x) ~= x, x = lab(x); end
    end
end

function s = spanOf(g)
f = [];
for k = 1:2, for t = g{k}(:)', f = [f; double(t.frames(:))]; end, end %#ok<AGROW>
s = [min(f) max(f)];
end
