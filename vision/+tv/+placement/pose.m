function cam = pose(pos, yawDeg, pitchDeg)
%POSE  Camera at pos (1-by-3, m), turned yawDeg from the +x axis toward +y
%   and tilted pitchDeg (negative = down). No roll: the image is level.
%   cam.R rows: right, down, forward (the optical axis).
[R1, R2, R3] = tv.placement.cameraAxes(yawDeg, pitchDeg);
cam.pos = pos;
cam.R   = [R1; R2; R3];
cam.yaw = yawDeg;  cam.pitch = pitchDeg;
end
