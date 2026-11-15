function [px, ok] = project(cam, P)
%PROJECT  Image pixels (N-by-2, 1-based column and row) of court points P (N-by-3).
%   ok is false for points behind the camera, off the lens model, or outside
%   the frame.
[u, v, ok] = tv.lens.project(cam.lens, cam, P);
px = [u + (cam.width + 1) / 2, v + (cam.height + 1) / 2];
ok = ok & px(:,1) >= 0.5 & px(:,1) <= cam.width + 0.5 & px(:,2) >= 0.5 & px(:,2) <= cam.height + 0.5;
end
