function R = fromPlay(R, rows, rec, sync, o)
%FROMPLAY  Rally windows from where the ball was in play, with every frame searched (Chris, 20 Nov).
%   R = tv.rally.fromPlay(R, rows, rec, sync, opts)
%   R: tv.rally.fromAudio's result (windows from the sound). rows{k}: camera k's scored spots over
%   every frame ([frame u v score ...], tv.detect.learnedCandidates). The session's time is cut into
%   bins of o.binS seconds; a bin is in play when, in either camera, at least o.binShare of its frames
%   hold a spot scoring over o.score. Bins in play less than o.mergeS apart are joined, then each
%   stretch runs from o.leadS before to o.tailS after (TV-RAL-02). The windows used are these joined
%   with the sound's (nothing either finds is left out: "when in doubt, keep footage").
%   Also returned, for judging a cheaper first pass later (Chris: switch only when it misses under
%   1% and he agrees): R.soundWindows (the sound's own), R.playSeconds (time in play) and
%   R.soundCoverage (the share of that time inside the sound's windows).
T = rec(1).pts(end);
edges = 0:o.binS:T + o.binS;
nb = numel(edges) - 1;
active = false(1, nb);
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
