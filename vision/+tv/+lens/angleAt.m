function theta = angleAt(lens, rho)
%ANGLEAT  Off-axis angle (rad) that lands at image radius rho (half-widths).
%   The inverse of tv.lens.radius, solved by Newton's method.
theta = atan(rho / 1.2);                      % starting guess
for k = 1:50
    switch lens.type
        case 'rectilinear'
            f = lens.F * tan(theta) - rho;   df = lens.F ./ cos(theta).^2;
        case 'radial'
            f = lens.c1*theta + lens.c3*theta.^3 - rho;   df = lens.c1 + 3*lens.c3*theta.^2;
    end
    theta = theta - f ./ df;
end
end
