% Flight model and RK4 integrator (TV-PHY-01; TV-TST-02).
base = tv.physics.defaultParams();

%% With no air the flight is the textbook parabola
prm = base;  prm.rho = 0;
[t, P] = tv.physics.simulate([0 0 1], [20 0 5], prm, 1);
exact = [20*t, 0*t, 1 + 5*t - 0.5*prm.g*t.^2];
assert(max(abs(P(:) - exact(:))) < 1e-9)

%% Drag on a 25 m/s ball is about 11.6 m/s^2, more than gravity (spec Part 5)
prm = base;  prm.rho = 1.20;
a = tv.physics.acceleration([25 0 0], prm);
assert(abs(-a(1) - 11.6) < 0.1)

%% RK4 at 1 ms agrees with ode45 within 1 mm, with drag, lift and wind
prm = base;  prm.CL = 0.25;  prm.spinAxis = [0 0.8 0.6];  prm.wind = [-3 1.5 0];
p0 = [-11 1 1];  v0 = [28 -2 4];  T = 1.5;
[~, P] = tv.physics.simulate(p0, v0, prm, T);
rhs = @(~, s) [s(4:6); tv.physics.acceleration(s(4:6)', prm)'];
[~, S] = ode45(rhs, [0 T], [p0 v0]', odeset('RelTol', 1e-10, 'AbsTol', 1e-12));
assert(norm(P(end, :) - S(end, 1:3)) < 1e-3)

%% Topspin lands shorter than no spin, and slice lands longer
% A groundstroke from the baseline: 25 m/s forward, 6 m/s up, from 1 m high
spins = {[0 0 0], [0 1 0], [0 -1 0]};          % none, topspin, slice
x = zeros(1, 3);
for k = 1:3
    prm = base;  prm.CL = 0.2 * any(spins{k});  prm.spinAxis = spins{k};
    [~, P] = tv.physics.simulate([-11.885 0 1], [25 0 6], prm, 3);
    hit = tv.physics.groundHit(P);
    x(k) = hit(1);
end
assert(x(2) < x(1) && x(1) < x(3))

%% A 3 m/s headwind on a 25 m/s ball raises drag by about 25%
prm = base;  still = tv.physics.acceleration([25 0 0], prm);
prm.wind = [-3 0 0];  head = tv.physics.acceleration([25 0 0], prm);
assert(abs(head(1) / still(1) - (28/25)^2) < 1e-9)


%% Lift following the spin (liftModel 'spin', 21 Nov) matches an ode45 flight made the same way
c = tv.court.constants();  q = tv.physics.defaultParams();
q.CD = 0.507;  q.CL0 = 0.25;  q.clScale = 1;  q.spinTau = 5;  q.gust = [];  q.t0 = 0;
v0 = [28 1 3];  ax = cross(v0 / norm(v0), [0 0 1]);  q.spinAxis = -ax / norm(ax);
[tT, PT] = tv.physics.truthFlight([-11.9 0 1], v0, q, 1.2);
p = tv.physics.defaultParams();  p.CD = 0.507;  p.CL = 0.25;  p.spinAxis = q.spinAxis;  p.liftModel = 'spin';  p.spinTau = 5;
[tS, PS] = tv.physics.simulate([-11.9 0 1], v0, p, 1.2);
d = max(sqrt(sum((interp1(tS, PS, tT) - PT) .^ 2, 2)));
p.liftModel = 'constant';  [~, PC] = tv.physics.simulate([-11.9 0 1], v0, p, 1.2);
dc = max(sqrt(sum((interp1(tS, PC, tT) - PT) .^ 2, 2)));
fprintf('lift following spin: %.2f mm from ode45 over 1.2 s (constant lift: %.0f mm)\n', 1000 * d, 1000 * dc);
assert(d < 0.002 && dc > 0.05)
