function R = fromPlay(R, rows, rec, sync, o, cams, box)
%FROMPLAY  Rally windows from where the ball was in play, with every frame searched (Chris, 20 Nov).
%   R = tv.rally.fromPlay(R, rows, rec, sync, opts, cams, box)
%   R: tv.rally.fromAudio's result (windows from the sound). rows{k}: camera k's scored spots over
%   every frame ([frame u v score ...], tv.detect.learnedCandidates). The session's time is cut into
%   bins of o.binS seconds; a bin is in play when, in either camera, at least o.binShare of its frames
%   hold a spot scoring over o.score. With cams (the fitted cameras) and box (tv.court.interest),
%   a spot counts only when it pairs with one in the other camera at the same moment: the two
%   sight lines pass within o.pairGapM of each other at a point inside Chris's court of interest,
%   at least o.minHeightM up, and it moves like a ball in flight: another such point within o.linkS
%   lies at a speed between o.minSpeed and o.maxSpeed (m/s). A neighbour's ball (outside the box), a
%   ball rolling on the court (too low) and the odd confident spot on a walking player (too slow)
%   then no longer join Chris's rallies into one (CI run 55: in adjacentTest the whole clip became
%   one rally, in pipelineTest the two rallies became one). Bins in play less than o.mergeS apart are joined, then each
%   stretch runs from o.leadS before to o.tailS after (TV-RAL-02). The windows used are these joined
%   with the sound's (nothing either finds is left out: "when in doubt, keep footage").
%   Also returned, for judging a cheaper first pass later (Chris: switch only when it misses under
%   1% and he agrees): R.soundWindows (the sound's own), R.playSeconds (time in play) and
%   R.soundCoverage (the share of that time inside the sound's windows).
T = rec(1).pts(end);
edges = 0:o.binS:T + o.binS;
nb = numel(edges) - 1;
active = false(1, nb);
if nargin >= 7 && ~isempty(cams)
    f = pairedFrames(rows, rec, sync, o, cams, box);   % camera 1's frames with a paired spot in the box
    if ~isempty(f)
        t = rec(1).pts(f + 1) + sync.startOffset(1);
        hit = histc(t(:)', edges);  hit = hit(1:nb);
        active = hit >= o.binShare * max(1, o.binS * rec(1).fps);
    end
else
    for k = 1:numel(rows)
        r = double(rows{k});
        if isempty(r), continue; end
        f = unique(r(r(:, 4) > o.score, 1));                 % frames (0-based) with a confident spot
        f = f(f >= 0 & f < numel(rec(k).pts));
        t = rec(k).pts(f + 1) + sync.startOffset(k);          % on camera 1's clock (coarse timing is enough here)
        hit = histc(t(:)', edges);  hit = hit(1:nb);
        perBin = max(1, o.binS * rec(k).fps);
        active = active | hit >= o.binShare * perBin;
    end
end
win = zeros(0, 2);
on = find(active);
if ~isempty(on)
    a = edges(on(1));  b = edges(on(1) + 1);
    for i = on(2:end)
        if edges(i) - b < o.mergeS, b = edges(i + 1); else, win(end+1, :) = [a b]; a = edges(i); b = edges(i + 1); end %#ok<AGROW>
    end
    win(end+1, :) = [a b];
end
playSeconds = sum(diff(win, 1, 2));
win = [max(0, win(:, 1) - o.leadS), min(T, win(:, 2) + o.tailS)];
snd = R.windows;
% how much of the time in play the sound's windows hold
cov = 0;
for i = 1:size(win, 1)
    for j = 1:size(snd, 1)
        cov = cov + max(0, min(win(i, 2), snd(j, 2)) - max(win(i, 1), snd(j, 1)));
    end
end
R.soundWindows = snd;
R.playWindows = win;
R.playSeconds = playSeconds;
R.soundCoverage = cov / max(sum(diff(win, 1, 2)), eps);
% both, joined where they overlap or are less than o.mergeS apart
both = sortrows([win; snd]);
out = zeros(0, 2);
for i = 1:size(both, 1)
    if ~isempty(out) && both(i, 1) - out(end, 2) < o.mergeS, out(end, 2) = max(out(end, 2), both(i, 2));
    else, out(end+1, :) = both(i, :); end %#ok<AGROW>
end
R.windows = out;
end

function f = pairedFrames(rows, rec, sync, o, cams, box)
% camera 1's frames holding a confident spot that a confident spot in camera 2's nearest frame
% meets in 3D (sight lines within o.pairGapM) inside the box
f = zeros(0, 1);
r1 = double(rows{1});  r2 = double(rows{2});
if isempty(r1) || isempty(r2), return; end
r1 = r1(r1(:, 4) > o.score, 1:3);  r2 = r2(r2(:, 4) > o.score, 1:3);
r1 = r1(r1(:, 1) >= 0 & r1(:, 1) < numel(rec(1).pts), :);
if isempty(r1) || isempty(r2), return; end
t1 = rec(1).pts(r1(:, 1) + 1) + sync.startOffset(1);
t2all = rec(2).pts(:) + sync.startOffset(2);
j = round(interp1(t2all, (0:numel(t2all) - 1)', t1(:), 'linear', NaN));
r2 = sortrows(r2, 1);
[u2, first2] = unique(r2(:, 1), 'first');
last2 = [first2(2:end) - 1; size(r2, 1)];
[ok, loc] = ismember(j, u2);
i1 = find(ok);
if isempty(i1), return; end
a = first2(loc(i1));  b = last2(loc(i1));
n = b - a + 1;
idx1 = repelem(i1, n);
idx2 = cell2mat(arrayfun(@(x, y) (x:y)', a, b, 'UniformOutput', false));
[P, gap] = tv.recon.triangulate(cams(1), r1(idx1, 2:3), cams(2), r2(idx2, 2:3));
inBox = P(:, 1) >= box.x(1) & P(:, 1) <= box.x(2) & P(:, 2) >= box.y(1) & P(:, 2) <= box.y(2) & ...
    P(:, 3) >= box.z(1) & P(:, 3) <= box.z(2);
good = gap < o.pairGapM & inBox & P(:, 3) >= o.minHeightM;
F = r1(idx1(good), 1);  P = P(good, :);
% moving like a ball in flight: linked to another point within o.linkS at a ball's speed
[F, o2] = sort(F);  P = P(o2, :);
n = numel(F);  moving = false(n, 1);
maxF = max(1, ceil(o.linkS * rec(1).fps));
for d = 1:8                                             % the next few points (a frame may hold more than one)
    if d >= n, break; end
    a = 1:n - d;  b = a + d;
    df = F(b) - F(a);
    sp = sqrt(sum((P(b, :) - P(a, :)).^2, 2)) ./ max(df, 1) * rec(1).fps;
    link = df >= 1 & df <= maxF & sp >= o.minSpeed & sp <= o.maxSpeed;
    moving(a(link)) = true;  moving(b(link)) = true;
end
f = unique(F(moving));
end
