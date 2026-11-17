function [kept, gone] = dropAtPlayer(trk, P, share)
%DROPATPLAYER  Drop tracks that never leave a player: racquets and shirts, not the ball.
%   [kept, gone] = tv.track.dropAtPlayer(trk, P) keeps the tracks of trk (tv.track.ball2d)
%   that are away from every player at least once. P holds the players' outlines at
%   sample frames: P.frames (vector) and P.boxes (cell, one [u0 v0 u1 v1] row per
%   player, already widened for arms and racquet). A track is checked at every sample
%   frame inside its span (its nearest point within 2 frames); it is a player's when
%   at least share (default 1: all) of those points lie inside a player's outline.
%   gone: logical, one per track.
%   Why (Chris, 17 Nov): racquet strings and a pale green shirt passed as the ball on
%   the first real footage. A racquet stays with its player for its whole track; the
%   ball at contact is beside the player for a few frames and then flies off, so its
%   track is kept. Tracks with no sample frame in their span are kept.
%   RETUNE(real footage): share; the outline's widening (runSingle's hitReach).
if nargin < 3, share = 1; end
gone = false(size(trk));
for i = 1:numel(trk)
    f = double(trk(i).frames(:));
    s = find(P.frames >= f(1) & P.frames <= f(end));
    n = 0;  in = 0;
    for j = s(:)'
        [d, k] = min(abs(f - P.frames(j)));
        if d > 2, continue; end
        n = n + 1;
        b = P.boxes{j};
        p = trk(i).uv(k, :);
        if ~isempty(b) && any(p(1) >= b(:, 1) & p(1) <= b(:, 3) & p(2) >= b(:, 2) & p(2) <= b(:, 4))
            in = in + 1;
        end
    end
    gone(i) = n > 0 && in >= share * n;
end
kept = trk(~gone);
end
