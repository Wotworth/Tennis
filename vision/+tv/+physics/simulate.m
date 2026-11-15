function [t, P, V] = simulate(p0, v0, prm, tEnd, dt, stopZ)
%SIMULATE  Ball flight by fixed-step 4th-order Runge-Kutta (TV-PHY-01).
%   [t, P, V] = simulate(p0, v0, prm, tEnd) integrates from position p0 (m)
%   and velocity v0 (m/s) for tEnd seconds at the default 1 ms step, using
%   the force model of tv.physics.acceleration (gravity, drag, Magnus).
%   A fixed step makes every run identical and fast; the tests check it
%   against ode45.
%   simulate(..., dt, stopZ) stops at the first step whose ball centre is
%   below stopZ (m), e.g. the ball radius for the bounce. The last sample is
%   then just under stopZ; tv.physics.groundHit interpolates the touch.
if nargin < 5 || isempty(dt), dt = 1e-3; end
if nargin < 6, stopZ = -Inf; end
n = round(tEnd / dt);
P = zeros(n + 1, 3);  V = zeros(n + 1, 3);
P(1, :) = p0(:)';  V(1, :) = v0(:)';
% The force model of tv.physics.acceleration, inlined for speed
k  = 0.5 * prm.rho * prm.area / prm.mass;
kD = k * prm.CD;  kL = k * prm.CL;
w  = prm.wind(:)';  ax = prm.spinAxis(:)';  g = [0 0 -prm.g];
last = n + 1;
for i = 1:n
    p = P(i, :);  v = V(i, :);
    k1v = acc(v);            k1p = v;
    k2v = acc(v + dt/2*k1v); k2p = v + dt/2*k1v;
    k3v = acc(v + dt/2*k2v); k3p = v + dt/2*k2v;
    k4v = acc(v + dt*k3v);   k4p = v + dt*k3v;
    V(i+1, :) = v + dt/6 * (k1v + 2*k2v + 2*k3v + k4v);
    P(i+1, :) = p + dt/6 * (k1p + 2*k2p + 2*k3p + k4p);
    if P(i+1, 3) < stopZ, last = i + 1; break; end
end
P = P(1:last, :);  V = V(1:last, :);
t = (0:last-1)' * dt;

    function a = acc(v)
        u = v - w;  s = sqrt(u * u');
        a = g - kD * s * u;
        if kL ~= 0 && s > 0
            a = a + kL * s * [ax(2)*u(3) - ax(3)*u(2), ax(3)*u(1) - ax(1)*u(3), ax(1)*u(2) - ax(2)*u(1)];
        end
    end
end
