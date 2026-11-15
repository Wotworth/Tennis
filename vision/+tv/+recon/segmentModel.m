function [P, V] = segmentModel(x, t0, t, air)
%SEGMENTMODEL  Ball centre at times t for one flight segment's parameters (TV-PHY-02).
%   x = [p0(3) v0(3) a1 a2 CD]: start position and velocity at time t0, the
%   Magnus push as two components across the flight path, and the drag
%   coefficient. a1 is the topspin (+) / slice (-) part, which pushes down
%   or up; a2 the sidespin part, which pushes sideways. Spin about the
%   direction of travel pushes nothing and is not modelled.
%   air: rho, wind, mass, area, g (tv.physics.defaultParams fields).
x = x(:)';
[e1, e2] = tv.recon.spinBasis(x(4:6));
a  = x(7) * e1 + x(8) * e2;                 % CL times the spin axis
prm = air;  prm.CD = x(9);
prm.CL = norm(a);
if prm.CL > 0, prm.spinAxis = a / prm.CL; else, prm.spinAxis = e1; end
tEnd = max(t(:)) - t0;
[ts, Ps, Vs] = tv.physics.simulate(x(1:3), x(4:6), prm, max(tEnd, 0) + 0.002);
P = interp1(ts, Ps, t(:) - t0, 'linear', 'extrap');
if nargout > 1, V = interp1(ts, Vs, t(:) - t0, 'linear', 'extrap'); end
end
