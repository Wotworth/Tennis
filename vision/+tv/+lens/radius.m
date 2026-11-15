function rho = radius(lens, theta)
%RADIUS  Image radius in half-widths for the off-axis angle theta (rad).
switch lens.type
    case 'rectilinear'
        rho = lens.F * tan(theta);
    case 'radial'
        rho = lens.c1 * theta + lens.c3 * theta.^3;
end
end
