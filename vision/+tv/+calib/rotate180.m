function cam = rotate180(cam)
%ROTATE180  The same camera under the court's half-turn symmetry.
%   A court looks the same after a half turn about the vertical line through
%   its centre (x -> -x, y -> -y): the ends swap and so do the sides. So
%   every pose found from the lines has a twin that sees exactly the same
%   picture. Which twin is right is settled by the other camera
%   (tv.calib.resolveSymmetry).
Rz = diag([-1 -1 1]);
cam.pos = cam.pos * Rz;
cam.R   = cam.R * Rz;
end
