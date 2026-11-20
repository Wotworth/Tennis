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
%   Lift: constant prm.CL by default. With prm.liftModel 'spin' (21 Nov, the spin-effect tail), prm.CL
%   is the lift at launch and the lift then follows the spin parameter S = r*omega/|u| through the
%   C_L(S) curve (tv.physics.liftCurve) as the ball slows, with the spin decaying as
%   exp(-t / prm.spinTau): what a real ball does, instead of one lift for the whole flight.
if nargin < 5 || isempty(dt), dt = 1e-3; end
if nargin < 6, stopZ = -Inf; end
n = round(tEnd / dt);
P = zeros(n + 1, 3);  V = zeros(n + 1, 3);
P(1, :) = p0(:)';  V(1, :) = v0(:)';
% The force model of tv.physics.acceleration, inlined for speed
k  = 0.5 * prm.rho * prm.area / prm.mass;
kD = k * prm.CD;  kL = k * prm.CL;
w  = prm.wind(:)';  ax = prm.spinAxis(:)';  g = [0 0 -prm.g];
spin = isfield(prm, 'liftModel') && strcmp(prm.liftModel, 'spin') && prm.CL > 0;
if spin
    % the lift curve inlined (tv.physics.liftCurve): C_L = a + b S above s1, through zero below
    ca = 0.03;  cb = 0.51;  s1 = 0.14;  cm = (ca + cb * s1) / s1;  cc = tv.court.constants();  r = cc.ballRadius;
    tau = 5;  if isfield(prm, 'spinTau'), tau = prm.spinTau; end
    S0 = prm.CL / cm;  if prm.CL >= ca + cb * s1, S0 = (prm.CL - ca) / cb; end
    u0 = norm(v0(:)' - w);  w0 = S0 * u0 / r;
end
last = n + 1;
for i = 1:n
    p = P(i, :);  v = V(i, :);  ti = (i - 1) * dt;
    k1v = acc(v, ti);              k1p = v;
    k2v = acc(v + dt/2*k1v, ti + dt/2); k2p = v + dt/2*k1v;
    k3v = acc(v + dt/2*k2v, ti + dt/2); k3p = v + dt/2*k2v;
    k4v = acc(v + dt*k3v, ti + dt);     k4p = v + dt*k3v;
    V(i+1, :) = v + dt/6 * (k1v + 2*k2v + 2*k3v + k4v);
    P(i+1, :) = p + dt/6 * (k1p + 2*k2p + 2*k3p + k4p);
    if P(i+1, 3) < stopZ, last = i + 1; break; end
end
P = P(1:last, :);  V = V(1:last, :);
t = (0:last-1)' * dt;

    function a = acc(v, tt)
        u = v - w;  s = sqrt(u * u');
        a = g - kD * s * u;
        if kL ~= 0 && s > 0
            kk = kL;
            if spin
                S = r * w0 * exp(-tt / tau) / s;
                if S >= s1, cl = ca + cb * S; else, cl = cm * S; end
                kk = k * cl;
            end
            a = a + kk * s * [ax(2)*u(3) - ax(3)*u(2), ax(3)*u(1) - ax(1)*u(3), ax(1)*u(2) - ax(2)*u(1)];
        end
    end
end
