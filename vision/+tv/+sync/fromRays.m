function [delta, curve] = fromRays(tracksByCam, cams, rec, sync, searchMs, centre)
%FROMRAYS  Camera 2's clock offset that makes the two cameras' sight lines meet.
%   For a trial offset, camera 1's ball track is interpolated to each
%   instant camera 2 saw the ball, and the two sight lines are triangulated.
%   With the right offset they cross (gap near 0); with a wrong one the ball
%   has moved, and they miss. The median gap over all fast ball points is
%   minimised over +/- searchMs milliseconds (default 60) in 0.5 ms steps,
%   then refined. This is the bridge from the coarse start-time sync (a frame
%   or two) to the fine fit (TV-SYNC-03).
%   RETUNE(real footage): the search range (+/- 60 ms) if GPS or timecode sync
%   turns out worse than a frame or two.
%   centre (s, default 0): search around this offset instead of zero
%   (tv.sync.clockLine follows the drift through a long session this way).
if nargin < 5 || isempty(searchMs), searchMs = 60; end
if nargin < 6, centre = 0; end
s = sync;  s.delta = 0;
P = tv.recon.pieces(tracksByCam, rec, s);
p1 = P([P.cam] == 1);  p2 = P([P.cam] == 2);
grid = centre + (-searchMs:0.5:searchMs) / 1000;
curve = nan(size(grid));
for g = 1:numel(grid)
    gaps = [];
    for a = p1(:)'
        for b = p2(:)'
            tb = b.t + grid(g);
            in = tb > a.tStart & tb < a.tEnd;
            if nnz(in) < 3, continue; end
            [ta, o] = sort(a.t);  uv = a.obs(o, 3:4);
            q = [interp1(ta, uv(:,1), tb(in)), interp1(ta, uv(:,2), tb(in))];
            [~, gp] = tv.recon.triangulate(cams(1), q, cams(2), b.obs(in, 3:4));
            gaps = [gaps; gp]; %#ok<AGROW>
        end
    end
    if numel(gaps) >= 10, curve(g) = median(gaps); end
end
[~, i] = min(curve);
if isnan(curve(i)), delta = centre; return; end
% parabola through the minimum and its neighbours
i = min(max(i, 2), numel(grid) - 1);
y = curve(i-1:i+1);  x = grid(i-1:i+1);
if all(isfinite(y))
    c = polyfit(x, y, 2);
    delta = -c(2) / (2 * c(1));
    if ~(delta >= x(1) && delta <= x(3)), delta = grid(i); end
else
    delta = grid(i);
end
end
