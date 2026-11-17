function hid = hiddenByNet(cam, P, marginM)
%HIDDENBYNET  Court points a camera sees only through the net, or not at all (17 Nov).
%   P: N-by-3 points (court frame). A point on the far side of the net (from this camera) is
%   hidden when the sight line from the camera to it crosses the net plane (x = 0) below the
%   net's top plus marginM (default 0.1 m): it is behind the tape or the mesh. From a camera
%   about 3 m up, 6 m behind a baseline, the far service line is hidden this way (right
%   behind the tape, Chris's first footage) and the far baseline is not. Such points are left
%   out when a pose is fitted or judged: the net tape would otherwise pass for them.
if nargin < 3, marginM = 0.1; end
hid = false(size(P, 1), 1);
c = cam.pos;
far = sign(P(:, 1)) ~= sign(c(1)) & P(:, 1) ~= 0;
if ~any(far), return; end
s = c(1) ./ (c(1) - P(far, 1));               % fraction of the way to the point at x = 0
yAt = c(2) + s .* (P(far, 2) - c(2));
zAt = c(3) + s .* (P(far, 3) - c(3));
hid(far) = zAt < tv.court.netHeight(yAt) + marginM & abs(yAt) <= tv.court.constants().postY;
end
