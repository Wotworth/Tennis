function lens = fromCalibration(file)
%FROMCALIBRATION  A camera's lens from its checkerboard calibration (TV-CAL-01, TV-CAL-02).
%   lens = tv.lens.fromCalibration('intrinsics_<serial>_<mode>.json') reads what the checkerboard
%   step wrote (vision/ml/lens_from_checkerboard.py, or the PC's MATLAB step): type calibStandard or
%   calibFisheye, focal length f (px), the picture centre's offset cx, cy (px from the middle,
%   0-based pixel conventions), pixel aspect fy/fx, radial terms k, picture size and the fit's
%   error. The result replaces tv.lens.build's published-angle model in tv.lens.project/unproject.
%   Pixel conventions: tv.camera.project adds (W+1)/2 to u, which is (W-1)/2 for 0-based pixels plus
%   one for MATLAB's 1-based ones, so cx carries over unchanged.
c = jsondecode(fileread(file));
lens.name = c.type;  lens.aspectName = '';
if isfield(c, 'mode'), lens.aspectName = c.mode; end
lens.type = c.type;
lens.widthPx = c.widthPx;  lens.heightPx = c.heightPx;
lens.fc = c.f / (c.widthPx / 2);                    % focal length in half-widths
lens.k = c.k(:)';
if strcmp(c.type, 'calibStandard'), lens.k(end+1:3) = 0; lens.thetaMax = 80;
else, lens.k(end+1:4) = 0; lens.thetaMax = 88; end
lens.cxPx = c.cx;  lens.cyPx = c.cy;  lens.aspect = c.aspect;
lens.rmsPx = c.rmsPx;
lens.serial = '';  if isfield(c, 'serial'), lens.serial = c.serial; end
end
