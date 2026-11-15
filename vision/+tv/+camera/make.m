function cam = make(lens, pos, yawDeg, pitchDeg, rollDeg)
%MAKE  Camera: lens, position (court frame, m) and orientation.
%   yaw from +x toward +y, pitch up positive, roll clockwise positive as the
%   camera sees it. cam.R rows are the camera's right, down and forward axes
%   in court coordinates.
if nargin < 5, rollDeg = 0; end
[r, d, f] = tv.placement.cameraAxes(yawDeg, pitchDeg);
cr = cosd(rollDeg);  sr = sind(rollDeg);
cam.lens = lens;
cam.pos  = pos(:)';
cam.R    = [cr*r + sr*d; -sr*r + cr*d; f];
cam.width = lens.widthPx;  cam.height = lens.heightPx;
end
