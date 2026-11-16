function [t, P, V, info] = truthFlight(p0, v0, q, tEnd, stopZ)
%TRUTHFLIGHT  A ball flight for SYNTHETIC TRUTH, deliberately unlike the fitter's model (TV-TST-01).
%   The fitter (tv.recon.segmentModel, tv.physics.simulate) assumes, within
%   one flight: fixed-step RK4, constant C_D, constant C_L and spin axis, and
%   steady wind. Testing it against flights made the same way would test the
%   fit against itself (Chris, 16 Nov). So the truth used by the synthetic
%   generators differs on every one of those:
%   - integrator: ode45 with tight tolerances, not RK4;
%   - spin decays: omega(t) = omega0 * exp(-t / q.spinTau);
%   - C_L follows the spin parameter S = r*omega/|u| through the C_L(S)
%     curve (tv.physics.liftCurve), so it changes as the ball slows and the
%     spin decays, times a per-shot scatter factor q.clScale;
%   - C_D is per shot (q.CD, drawn by the caller with Cross & Lindsey's spread);
%   - wind gusts: q.wind plus tv.physics.gust(q.gust, q.t0 + t).
%   q: rho, area, mass, g, CD, CL0 (lift at launch, before scatter: sets
%   omega0), clScale, spinAxis, spinTau (s), wind (1x3 mean), gust, t0
%   (session time of the launch). Output on a 1 ms grid; with stopZ the
%   flight ends where the ball centre comes down to stopZ (last sample exactly
%   there). info.omega0 (rad/s) and info.rpm0 for the truth record.
if nargin < 5, stopZ = -Inf; end
c = tv.court.constants();
u0 = norm(v0 - q.wind);
S0 = tv.physics.liftCurve(q.CL0, 'inverse');
omega0 = S0 * u0 / c.ballRadius;
info.omega0 = omega0;  info.rpm0 = omega0 * 60 / (2 * pi);
k = 0.5 * q.rho * q.area / q.mass;
    function dy = f(tt, y)
        w = q.wind + tv.physics.gust(q.gust, q.t0 + tt);
        u = y(4:6)' - w;  s = norm(u);
        a = [0 0 -q.g] - k * q.CD * s * u;
        om = omega0 * exp(-tt / q.spinTau);
        if om > 0 && s > 0
            CL = q.clScale * tv.physics.liftCurve(c.ballRadius * om / s);
            a = a + k * CL * s^2 * cross(q.spinAxis, u / s);
        end
        dy = [y(4:6); a'];
    end
    function [val, term, dir] = ground(~, y)
        val = y(3) - stopZ;  term = 1;  dir = -1;
    end
grid = (0:1e-3:tEnd)';
o = odeset('RelTol', 1e-9, 'AbsTol', 1e-10);
if isfinite(stopZ), o = odeset(o, 'Events', @ground); end
[t, Y, te, ye] = ode45(@f, grid, [p0(:); v0(:)], o);
if ~isempty(te) && t(end) < te(end) - 1e-12
    t = [t; te(end)];  Y = [Y; ye(end, :)];
end
P = Y(:, 1:3);  V = Y(:, 4:6);
end
