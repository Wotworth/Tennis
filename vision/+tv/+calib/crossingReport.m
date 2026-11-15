function rep = crossingReport(cams, opts)
%CROSSINGREPORT  How well the two cameras' sight lines cross, all over the court.
%   Where the lines from the two cameras to a point cross at a shallow
%   angle, distance along them is poorly measured. The angle is computed on
%   a grid over the court and 3 m behind each baseline, at the ground and at
%   1.5 m, folded so 170 deg counts as 10 deg. The court is split into nine
%   zones (three along it: camera 1's end, the middle by the net, camera
%   2's end; three across: the cameras' side, the centre, the far side).
%   A zone is flagged when its smallest angle is below opts.minDeg
%   (default 20) or part of it is not seen by both cameras.
%   rep.minDeg, rep.zones (name, minDeg, bothSeenPct), rep.low (names of
%   flagged zones), rep.text (one line for the alert).
%   RETUNE(real footage): the usable angle; check it against AC-08 results.
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'minDeg'), opts.minDeg = 20; end
c = tv.court.constants();
xe = c.halfLength + 3;
[gx, gy, gz] = ndgrid(linspace(-xe, xe, 45), linspace(-c.halfDoubles, c.halfDoubles, 21), [c.ballRadius 1.5]);
P = [gx(:), gy(:), gz(:)];
[~, ok1] = tv.camera.project(cams(1), P);
[~, ok2] = tv.camera.project(cams(2), P);
both = ok1 & ok2;
a = P - cams(1).pos;  b = P - cams(2).pos;
ang = acosd(max(-1, min(1, sum(a .* b, 2) ./ (sqrt(sum(a.^2, 2)) .* sqrt(sum(b.^2, 2))))));
ang = min(ang, 180 - ang);
% zones: along x relative to camera 1's end, across y relative to the cameras' side
s1 = sign(cams(1).pos(1));  if s1 == 0, s1 = -1; end
sy = sign(mean([cams(1).pos(2), cams(2).pos(2)]));  if sy == 0, sy = -1; end
u = P(:, 1) * s1;            % > 0 toward camera 1's end
v = P(:, 2) * sy;            % > 0 toward the cameras' side
along = {'camera 1''s end', 'the middle by the net', 'camera 2''s end'};
across = {'cameras'' side', 'centre', 'far side'};
ia = 1 + (u <= 4) + (u < -4);
ic = 1 + (v <= 1.8) + (v < -1.8);
rep.zones = struct('name', {}, 'minDeg', {}, 'bothSeenPct', {});
rep.low = {};
for i = 1:3
    for j = 1:3
        m = ia == i & ic == j;
        nm = sprintf('%s, %s', along{i}, across{j});
        mn = min([ang(m & both); Inf]);
        seen = 100 * mean(both(m));
        rep.zones(end+1) = struct('name', nm, 'minDeg', round(mn * 10) / 10, 'bothSeenPct', round(seen));
        if mn < opts.minDeg || seen < 100, rep.low{end+1} = nm; end
    end
end
rep.minDeg = min(ang(both));
rep.thresholdDeg = opts.minDeg;
if isempty(rep.low)
    rep.text = sprintf('Camera sight lines cross at %.0f deg or more everywhere on court.', rep.minDeg);
else
    parts = cellfun(@(n) sprintf('%s (%s)', n, describe(rep.zones(strcmp({rep.zones.name}, n)))), rep.low, 'UniformOutput', false);
    rep.text = sprintf('Weak camera angle (under %g deg, or seen by one camera) in: %s. Bounces and speeds there are less certain.', ...
        opts.minDeg, strjoin(parts, '; '));
end
end

function s = describe(z)
if z.bothSeenPct < 100, s = sprintf('%d%% seen by both', z.bothSeenPct);
else, s = sprintf('%.0f deg', z.minDeg); end
end
