function [t, P, V] = simulate(p0, v0, prm, tEnd, dt)
%SIMULATE  Ball flight by fixed-step 4th-order Runge-Kutta (TV-PHY-01).
%   [t, P, V] = simulate(p0, v0, prm, tEnd) integrates from position p0 (m)
%   and velocity v0 (m/s) for tEnd seconds at the default 1 ms step.
%   A fixed step makes every run identical and fast; the tests check it
%   against ode45. The flight is not stopped at the ground: callers find the
%   bounce themselves.
if nargin < 5, dt = 1e-3; end
n = round(tEnd / dt);
t = (0:n)' * dt;
P = zeros(n + 1, 3);  V = zeros(n + 1, 3);
P(1, :) = p0;  V(1, :) = v0;
f = @(v) tv.physics.acceleration(v, prm);    % gravity, drag and lift depend on v only
for i = 1:n
    p = P(i, :);  v = V(i, :);
    k1v = f(v);              k1p = v;
    k2v = f(v + dt/2*k1v);   k2p = v + dt/2*k1v;
    k3v = f(v + dt/2*k2v);   k3p = v + dt/2*k2v;
    k4v = f(v + dt*k3v);     k4p = v + dt*k3v;
    V(i+1, :) = v + dt/6 * (k1v + 2*k2v + 2*k3v + k4v);
    P(i+1, :) = p + dt/6 * (k1p + 2*k2p + 2*k3p + k4p);
end
end
