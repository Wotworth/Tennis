function [D, ok] = rays(cam, px)
%RAYS  Unit sight lines in court axes (N-by-3) through image pixels px (N-by-2, 1-based).
[d, ok] = tv.lens.unproject(cam.lens, px(:,1) - (cam.width + 1) / 2, px(:,2) - (cam.height + 1) / 2);
D = d * cam.R;          % camera axes -> court axes (rows of R are the axes)
end
