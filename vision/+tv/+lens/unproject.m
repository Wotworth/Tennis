function [d, ok] = unproject(lens, u, v)
%UNPROJECT  Sight-line directions (camera frame) for pixels (u, v).
%   u right and v down, in pixels from the image centre (as tv.lens.project).
%   d is N-by-3 unit vectors in camera axes (right, down, forward), one per
%   pixel. Inverse of tv.lens.toPixels.
u = u(:);  v = v(:);
if isfield(lens, 'cxPx')                      % a calibrated lens: its own centre and pixel aspect
    u = u - lens.cxPx;  v = (v - lens.cyPx) / lens.aspect;
end
rhoPx = hypot(u, v);
theta = tv.lens.angleAt(lens, rhoPx / (lens.widthPx / 2));
ok    = theta < deg2rad(lens.thetaMax);
s     = sin(theta) ./ max(rhoPx, eps);
d     = [u .* s, v .* s, cos(theta)];
d(rhoPx == 0, :) = repmat([0 0 1], nnz(rhoPx == 0), 1);
end
