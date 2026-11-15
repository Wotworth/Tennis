function sd = bounceSd(seg, air, cfg)
%BOUNCESD  1-sigma uncertainty (m) of a flight's bounce point, from its fit.
%   The fit's parameter covariance (pixel error squared times inv(J'J), J
%   the pixel residuals' sensitivity to the parameters) carried through to
%   the bounce point by finite differences. Returns the larger of the two
%   horizontal standard deviations.
c = tv.court.constants();
x = seg.x;  t = seg.t;  h = [1e-3 1e-3 1e-3 1e-3 1e-3 1e-3 1e-3 1e-3 1e-3];
r0 = pix(x);
J = zeros(numel(r0), 9);  G = zeros(2, 9);
g0 = ground(x);
for i = 1:9
    xi = x;  xi(i) = xi(i) + h(i);
    J(:, i) = (pix(xi) - r0) / h(i);
    gi = ground(xi);
    G(:, i) = (gi(1:2) - g0(1:2))' / h(i);
end
s2 = max(seg.rmsPx, 0.3)^2;
C = s2 * pinv(J' * J);
S = G * C * G';
sd = sqrt(max(eig(S)));

    function r = pix(x)
        P = tv.recon.segmentModel(x, seg.t0, t, air);
        r = [];
        for k = 1:2
            i = seg.obs(:, 1) == k;
            if ~any(i), continue; end
            px = cfg.cams(k);
            q = tv.camera.project(px, P(i, :));
            r = [r; q(:)]; %#ok<AGROW>
        end
    end
    function g = ground(x)
        q = air;  q.CD = x(9);
        [e1, e2] = tv.recon.spinBasis(x(4:6));  a = x(7) * e1 + x(8) * e2;
        q.CL = norm(a);  if q.CL > 0, q.spinAxis = a / q.CL; end
        [~, P] = tv.physics.simulate(x(1:3), x(4:6), q, 4, 1e-3, c.ballRadius);
        g = tv.physics.groundHit(P);
        if isempty(g), g = P(end, :); end
    end
end
