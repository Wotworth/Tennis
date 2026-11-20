function theta = angleAt(lens, rho)
%ANGLEAT  Off-axis angle (rad) that lands at image radius rho (half-widths).
%   The inverse of tv.lens.radius, solved by Newton's method (a numerical slope for the
%   calibrated models).
theta = atan(rho / 1.2);                      % starting guess
for k = 1:50
    switch lens.type
        case 'rectilinear'
            f = lens.F * tan(theta) - rho;   df = lens.F ./ cos(theta).^2;
        case 'radial'
            f = lens.c1*theta + lens.c3*theta.^3 - rho;   df = lens.c1 + 3*lens.c3*theta.^2;
        otherwise
            h = 1e-6;
            f = tv.lens.radius(lens, theta) - rho;
            df = (tv.lens.radius(lens, theta + h) - tv.lens.radius(lens, theta - h)) / (2 * h);
    end
    theta = theta - f ./ df;
    theta = min(max(theta, 0), deg2rad(89.9));
end
end
