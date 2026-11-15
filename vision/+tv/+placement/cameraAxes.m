function [right, down, fwd] = cameraAxes(yawDeg, pitchDeg)
%CAMERAAXES  Camera axes for column vectors of yaw and pitch angles (degrees).
%   Each output has one row per angle pair and three columns (x, y, z).
yawDeg = yawDeg(:);  pitchDeg = pitchDeg(:);
cy = cosd(yawDeg);  sy = sind(yawDeg);  cp = cosd(pitchDeg);  sp = sind(pitchDeg);
fwd   = [cp.*cy, cp.*sy, sp];
right = [sy, -cy, zeros(size(cy))];       % fwd x up, normalised: level horizon
down  = [sp.*cy, sp.*sy, -cp];            % fwd x right
end
