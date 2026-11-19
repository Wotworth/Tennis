function [x0, ok] = initOneCam(obs, t, cams, anchors, air, CD)
%INITONECAM  Starting values for a flight only one camera saw (TV-REC-01, Chris 18 Nov).
%   Each detection is a sight line from the camera; under gravity alone the ball's path
%   p0 + v0*tau - g*tau^2/2 must lie on every one of them at its time, and pass each pin
%   (anchors rows [t x y z sd]: where a neighbouring flight ended or began). Both conditions
%   are linear in p0 and v0, so one least-squares solve gives the start. Sight lines count
%   to about a centimetre across them, pins to their sd.
%   x0 = [p0 v0 0 0 CD] at the time of the first detection or pin, less 1 ms.
x0 = [];  ok = false;
k = obs(1, 1);
if any(obs(:, 1) ~= k) || size(obs, 1) < 4, return; end
t0 = min([t; anchors(:, 1)]) - 0.001;
d = tv.camera.rays(cams(k), obs(:, 3:4));           % unit sight lines, court axes
c = cams(k).pos(:)';
g = [0 0 -air.g];
n = size(obs, 1);  m = size(anchors, 1);
M = zeros(3 * (n + m), 6);  b = zeros(3 * (n + m), 1);
for i = 1:n
    tau = t(i) - t0;
    K = [0 -d(i, 3) d(i, 2); d(i, 3) 0 -d(i, 1); -d(i, 2) d(i, 1) 0];     % cross product with the sight line
    r = 3 * i - 2:3 * i;
    M(r, :) = [K, K * tau] / 0.01;
    b(r) = K * (c - g * tau^2 / 2)' / 0.01;
end
for j = 1:m
    tau = anchors(j, 1) - t0;
    r = 3 * (n + j) - 2:3 * (n + j);
    M(r, :) = [eye(3), eye(3) * tau] / anchors(j, 5);
    b(r) = (anchors(j, 2:4) - g * tau^2 / 2)' / anchors(j, 5);
end
if rank(M) < 6, return; end
q = (M \ b)';
x0 = [q(1:3), q(4:6), 0, 0, CD];
ok = all(isfinite(x0));
end
