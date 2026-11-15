function P = modelPoints(step)
%MODELPOINTS  Points (N-by-3, m) along the centre of every painted line and the net tape.
%   The net tape adds points 0.9-1.07 m off the ground, which pins down the
%   camera's height and tilt far better than ground lines alone (TV-CAL-12).
if nargin < 1, step = 0.05; end
c = tv.court.constants();
L = tv.court.lines();
P = zeros(0, 3);
for k = 1:size(L, 1)
    a = L(k, 1:2);  b = L(k, 3:4);
    n = max(2, ceil(norm(b - a) / step) + 1);
    t = linspace(0, 1, n)';
    P = [P; a + t .* (b - a), zeros(n, 1)]; %#ok<AGROW>
end
y = (-c.postY:step:c.postY)';
P = [P; zeros(size(y)), y, tv.court.netHeight(y) - 0.03];
end
