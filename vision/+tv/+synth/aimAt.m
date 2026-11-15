function [v0, hit] = aimAt(p0, target, speed, prm)
%AIMAT  Launch velocity that sends the ball from p0 to bounce at target [x y].
%   Fixed speed; solves for elevation and direction by Newton's method on the
%   simulated bounce point (gravity, drag, Magnus and wind all included).
c = tv.court.constants();
az = atan2d(target(2) - p0(2), target(1) - p0(1));
el = 4;
for it = 1:25
    [h, ok] = land(el, az);
    if ~ok, el = el + 3; continue; end
    err = target(:)' - h(1:2);
    if norm(err) < 0.005, break; end
    d = 0.05;
    J = [(land(el + d, az) - h)'/d, (land(el, az + d) - h)'/d];
    step = J(1:2, :) \ err';
    step = max(-8, min(8, step));
    el = el + step(1);  az = az + step(2);
end
v0  = speed * [cosd(el)*cosd(az), cosd(el)*sind(az), sind(el)];
hit = land(el, az);

    function [h, ok] = land(e, a)
        v = speed * [cosd(e)*cosd(a), cosd(e)*sind(a), sind(e)];
        [~, P] = tv.physics.simulate(p0, v, prm, 4, 1e-3, c.ballRadius);
        h = tv.physics.groundHit(P);
        ok = ~isempty(h);
        if ~ok, h = P(end, :); end
    end
end
