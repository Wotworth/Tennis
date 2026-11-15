function [P, gap] = triangulate(cam1, px1, cam2, px2)
%TRIANGULATE  Midpoint of the closest approach of two sight lines (linear triangulation).
%   px1, px2: N-by-2 pixels. P: N-by-3 court points; gap: N-by-1 distance (m)
%   between the two lines at their closest (0 for a perfect match; large
%   means the two pixels are not the same ball).
d1 = tv.camera.rays(cam1, px1);  d2 = tv.camera.rays(cam2, px2);
o1 = cam1.pos;  o2 = cam2.pos;  w = o1 - o2;
a = sum(d1.*d1, 2);  b = sum(d1.*d2, 2);  c = sum(d2.*d2, 2);
d = d1 * w';  e = d2 * w';
den = a .* c - b.^2;
s = (b .* e - c .* d) ./ den;  u = (a .* e - b .* d) ./ den;
p1 = o1 + s .* d1;  p2 = o2 + u .* d2;
P = (p1 + p2) / 2;  gap = sqrt(sum((p1 - p2).^2, 2));
end
