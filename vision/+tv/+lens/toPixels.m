function [u, v, ok] = toPixels(lens, Xc, Yc, Zc)
%TOPIXELS  Pixels from camera-frame coordinates (right, down, forward).
%   Works element by element on arrays of any size.
r     = sqrt(Xc.^2 + Yc.^2);
theta = atan2(r, Zc);
rhoPx = tv.lens.radius(lens, theta) * lens.widthPx / 2;
r(r == 0) = eps;
u  = rhoPx .* Xc ./ r;
v  = rhoPx .* Yc ./ r;
ok = theta < deg2rad(lens.thetaMax);
end
