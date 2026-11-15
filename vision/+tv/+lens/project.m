function [u, v, ok] = project(lens, cam, P)
%PROJECT  Pixel position of 3D points P (N-by-3, court frame) in a camera.
%   u is to the right and v down, in pixels from the image centre.
%   ok is false for points behind the camera or too far off-axis for the
%   lens model; their u and v are meaningless.
%   cam.pos is the lens position (1-by-3); cam.R has rows right, down and
%   forward (the optical axis), from tv.placement.pose.
Q  = P - cam.pos;
Xc = Q * cam.R(1, :)';
Yc = Q * cam.R(2, :)';
Zc = Q * cam.R(3, :)';
[u, v, ok] = tv.lens.toPixels(lens, Xc, Yc, Zc);
end
