function r = evaluate(cfg, lens, standoff, mountX, height, pts)
%EVALUATE  How well one camera pair placement covers and measures the court.
%   Both cameras on the same side, STANDOFF metres outside the doubles
%   sideline, at x = -mountX (camera 1) and +mountX (camera 2) along it, at
%   HEIGHT metres, with the same lens. PTS is the play volume
%   (tv.court.playVolume). Camera 1 is aimed by tv.placement.aim; camera 2 is
%   its mirror image, since the court is symmetric about the net.
%
%   Outputs (struct r):
%   coverage    smaller of the two cameras' fractions of PTS in frame, with the
%               aiming margin (1 = everything)
%   minCrossDeg smallest angle between the two sight lines over PTS, folded
%               so 170 deg counts as 10 deg (both are equally poor)
%   errorCm     1-sigma horizontal bounce error at the worse far corner, for
%               one frame from each camera with cfg.pixelSigma px of error
%   ballPx      smallest ball diameter, in pixels, at the far corners
%   yaw, pitch  camera 1's aim (camera 2: yaw 180 - yaw, same pitch)
c  = tv.court.constants();
cr = cfg.criteria;
y0 = -(c.halfDoubles + standoff);
pos1 = [-mountX, y0, height];
pos2 = [ mountX, y0, height];

marginPx = deg2rad(cr.aimToleranceDeg) * tv.lens.pxPerRad(lens);
[yaw, pitch, cov1] = tv.placement.aim(lens, pos1, pts, marginPx);
cam1 = tv.placement.pose(pos1, yaw, pitch);
cam2 = tv.placement.pose(pos2, 180 - yaw, pitch);
cov2 = coverageOf(cam2);

% Stereo crossing angle over the volume
a = pts - pos1;  b = pts - pos2;
cosAng = sum(a .* b, 2) ./ (sqrt(sum(a.^2, 2)) .* sqrt(sum(b.^2, 2)));
ang = acosd(max(-1, min(1, cosAng)));
r.minCrossDeg = min(min(ang, 180 - ang));

% Far corners: bounce error and ball size
far = [-c.halfLength, c.halfDoubles, c.ballRadius;
        c.halfLength, c.halfDoubles, c.ballRadius];
err = zeros(2, 1);  ball = zeros(2, 1);
for k = 1:2
    err(k)  = tv.placement.stereoError(lens, cam1, cam2, far(k, :), cr.pixelSigma);
    ball(k) = min(ballSize(cam1, far(k, :)), ballSize(cam2, far(k, :)));
end
r.coverage = min(cov1, cov2);
r.errorCm  = 100 * max(err);
r.ballPx   = min(ball);
r.yaw = yaw;  r.pitch = pitch;  r.cam1 = cam1;  r.cam2 = cam2;
r.standoff = standoff;  r.mountX = mountX;  r.height = height;
r.lens = lens.name;  r.aspect = lens.aspect;
% The crossing angle is reported (TV-CAL-04) but not a pass criterion: the
% error figure already accounts for it, and for the cameras' height.
r.passes = r.coverage >= 1 && r.errorCm <= cr.maxBounceErrorCm && r.ballPx >= cr.minBallPx;

    function cv = coverageOf(cam)
        [u, v, ok] = tv.lens.project(lens, cam, pts);
        in = ok & abs(u) <= lens.widthPx/2 - marginPx & abs(v) <= lens.heightPx/2 - marginPx;
        cv = mean(in);
    end

    function px = ballSize(cam, p)
        % Diameter across the sight line, in the two directions; the smaller.
        ray = (p - cam.pos) / norm(p - cam.pos);
        e1 = cross(ray, [0 0 1]);  e1 = e1 / norm(e1);
        e2 = cross(ray, e1);
        px = inf;
        for e = {e1, e2}
            [ua, va] = tv.lens.project(lens, cam, p + e{1} * c.ballRadius);
            [ub, vb] = tv.lens.project(lens, cam, p - e{1} * c.ballRadius);
            px = min(px, hypot(ua - ub, va - vb));
        end
    end
end
