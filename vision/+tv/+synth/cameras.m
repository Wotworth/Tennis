function cams = cameras(sc)
%CAMERAS  The two synthetic cameras: lens, pose and clock, as the scenario sets them.
%   Each camera is aimed the way tv.placement.aim recommends, then knocked
%   off by sc.aimErrorDeg (nobody mounts a camera perfectly), so the
%   pipeline must find the real pose from the court lines.
cfg  = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'config', 'placement.json'));
lens = tv.lens.build(cfg.lenses, sc.lensName, sc.aspect);
full = lens;
lens = tv.lens.atResolution(lens, sc.frameSize(1), sc.frameSize(2));
c    = tv.court.constants();
pts  = tv.court.playVolume(cfg.volume.behindBaseline, cfg.volume.maxHeight, cfg.volume.step);
pos1 = [-sc.mountX, -(c.halfDoubles + sc.standoff), sc.mountHeight];
margin = deg2rad(cfg.criteria.aimToleranceDeg) * tv.lens.pxPerRad(full);
[yaw, pitch] = tv.placement.aim(full, pos1, pts, margin);
plan = [yaw, pitch; 180 - yaw, pitch];
pos  = [pos1; sc.mountX, pos1(2), pos1(3)];
for k = 1:2
    e = sc.aimErrorDeg(k, :);
    cam = tv.camera.make(lens, pos(k, :), plan(k, 1) + e(1), plan(k, 2) + e(2), e(3));
    cam.fps = sc.fps;  cam.shutter = sc.shutter;  cam.readout = sc.readout(k);
    cam.clockOffset = sc.clockOffset(k);  cam.clockDrift = sc.clockDrift(k);
    cam.recordStart = sc.recordStart(k);  cam.serial = sc.serials{k};
    cam.plannedYaw = plan(k, 1);  cam.plannedPitch = plan(k, 2);
    cams(k) = cam; %#ok<AGROW>
end
end
