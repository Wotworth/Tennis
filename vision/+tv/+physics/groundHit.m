function [p, k] = groundHit(P, t)
%GROUNDHIT  Where a simulated flight first comes down to the ground.
%   The ball touches the ground when its centre is one radius up. Returns
%   that point (1-by-3), interpolated between the 1 ms samples of P (from
%   tv.physics.simulate), and its time if t is given (second output: the
%   sample index before the touch). Empty if it never comes down.
c = tv.court.constants();
z = P(:, 3) - c.ballRadius;
k = find(z(1:end-1) > 0 & z(2:end) <= 0, 1);
if isempty(k), p = []; return; end
f = z(k) / (z(k) - z(k+1));
p = P(k, :) + f * (P(k+1, :) - P(k, :));
if nargin > 1, k = t(k) + f * (t(k+1) - t(k)); end
end
