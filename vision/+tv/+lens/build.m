function lens = build(entries, name, aspect)
%BUILD  Lens model for one GoPro digital lens and aspect, from its published angles.
%   ENTRIES is the "lenses" list in config/placement.json: one entry per
%   lens and aspect, with horizontal, vertical and diagonal angles (degrees)
%   and the frame size in pixels.
%
%   Image radius is measured in units of the frame's half-width (rho = 1 at
%   the left and right edges).
%   - "rectilinear" (GoPro Linear): straight lines stay straight,
%     rho = F * tan(theta), with F set by the horizontal angle.
%   - "radial" (GoPro Wide): barrel distortion, rho = c1*theta + c3*theta^3,
%     fitted by least squares to every published angle of that lens (all
%     aspects at once).
%   theta is the angle between a sight line and the optical axis.
%   PROVISIONAL: replaced by the calibrated lens (TV-CAL-01) once a camera
%   exists.
%   RETUNE(real lens): the whole model; real files use the calibrated lens.

isLens = arrayfun(@(e) strcmp(e.name, name), entries);
isMode = isLens & arrayfun(@(e) strcmp(e.aspect, aspect), entries);
if ~any(isMode)
    error('tv:lens:unknown', 'No published angles for %s %s.', name, aspect);
end
e = entries(find(isMode, 1));

lens.name     = name;
lens.aspect   = aspect;
lens.widthPx  = e.widthPx;
lens.heightPx = e.heightPx;
lens.type     = e.model;

switch e.model
    case 'rectilinear'
        lens.F = 1 / tand(e.hfov / 2);
        lens.thetaMax = 89;                         % deg
    case 'radial'
        th = [];  rho = [];
        for k = reshape(find(isLens), 1, [])
            ek = entries(k);
            ar = ek.heightPx / ek.widthPx;          % half-height in half-widths
            th  = [th;  deg2rad([ek.hfov; ek.vfov; ek.dfov] / 2)];  %#ok<AGROW>
            rho = [rho; 1; ar; hypot(1, ar)];                       %#ok<AGROW>
        end
        cf = [th, th.^3] \ rho;
        lens.c1 = cf(1);  lens.c3 = cf(2);
        lens.thetaMax = 85;                         % deg; the fit is used only inside the frame
    otherwise
        error('tv:lens:model', 'Unknown lens model %s.', e.model);
end
end
