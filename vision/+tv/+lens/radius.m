function rho = radius(lens, theta)
%RADIUS  Image radius in half-widths for the off-axis angle theta (rad).
%   Published-angle models (tv.lens.build): rectilinear and radial. Calibrated models from a
%   checkerboard (tv.lens.fromCalibration, TV-CAL-01): calibStandard, rho = fc*t*(1 + k1 t^2 + k2 t^4
%   + k3 t^6) with t = tan(theta); calibFisheye, rho = fc*theta*(1 + k1 th^2 + ... + k4 th^8); fc is
%   the focal length in half-widths.
switch lens.type
    case 'rectilinear'
        rho = lens.F * tan(theta);
    case 'radial'
        rho = lens.c1 * theta + lens.c3 * theta.^3;
    case 'calibStandard'
        t = tan(theta);  t2 = t.^2;  k = lens.k;
        rho = lens.fc * t .* (1 + k(1) * t2 + k(2) * t2.^2 + k(3) * t2.^3);
    case 'calibFisheye'
        t2 = theta.^2;  k = lens.k;
        rho = lens.fc * theta .* (1 + k(1) * t2 + k(2) * t2.^2 + k(3) * t2.^3 + k(4) * t2.^4);
    otherwise
        error('tv:lens:model', 'Unknown lens model %s.', lens.type);
end
end
