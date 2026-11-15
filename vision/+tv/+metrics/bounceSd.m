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
for p = 1:9
    xi = x;  xi(p) = xi(p) + h(p);
    J(:, p) = (pix(xi) - r0) / h(p);
    gi = ground(xi);
    G(:, p) = (gi(1:2) - g0(1:2))' / h(p);
end
s2 = max(seg.rmsPx, 0.3)^2;
C = s2 * pinv(J' * J);
S = G * C * G';
sd = sqrt(max(eig(S)));

    % (nested functions share the caller's variables: their names are kept distinct)
    function rr = pix(xx)
        PP = tv.recon.segmentModel(xx, seg.t0, t, air);
        rr = [];
        for kk = 1:2
            sel = seg.obs(:, 1) == kk;
            if ~any(sel), continue; end
            qq = tv.camera.project(cfg.cams(kk), PP(sel, :));
            rr = [rr; qq(:)]; %#ok<AGROW>
        end
    end
    function gg = ground(xx)
        aa = air;  aa.CD = xx(9);
        [b1, b2] = tv.recon.spinBasis(xx(4:6));  sv = xx(7) * b1 + xx(8) * b2;
        aa.CL = norm(sv);  if aa.CL > 0, aa.spinAxis = sv / aa.CL; end
        [~, PG] = tv.physics.simulate(xx(1:3), xx(4:6), aa, 4, 1e-3, c.ballRadius);
        gg = tv.physics.groundHit(PG);
        if isempty(gg), gg = PG(end, :); end
    end
end
