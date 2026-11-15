function s = spin(x, air, cfg)
%SPIN  Spin figures for one flight (TV-SPN-02 to TV-SPN-04).
%   x: fitted segment parameters. The Magnus push splits into a topspin (+)
%   / slice (-) part and a sidespin part (TV-SPN-02). The lift coefficient
%   converts to a spin parameter S = r*omega/|u| through the C_L(S) table
%   (cfg.clTable: C_L = a + b*S, valid over cfg.sRange), then to rpm. Every
%   rpm carries about +/-25% for the table itself, combined with the fit's
%   own uncertainty (TV-SPN-04). Below S = cfg.flatBelow the shot is "flat /
%   low spin" and gets no rpm. Only spin across the flight path counts.
%   RETUNE(lab data): the table is the spec's straight line through the ends
%   of Cross & Lindsey's range; replace with a proper fit.
if nargin < 3 || isempty(cfg)
    cfg = struct('clTable', [0.03 0.51], 'sRange', [0.14 0.53], 'flatBelow', 0.1, 'modelSd', 0.25);
end
c = tv.court.constants();
s.top  = x(7);                 % + topspin, - slice (C_L units)
s.side = x(8);                 % sidespin (C_L units)
CL = hypot(x(7), x(8));
s.CL = CL;
S = (CL - cfg.clTable(1)) / cfg.clTable(2);
u = norm(x(4:6) - air.wind(:)');
s.S = S;
if S < cfg.flatBelow
    s.rpm = NaN;  s.rpmSd = NaN;  s.label = 'flat / low spin';
else
    omega = S * u / c.ballRadius;            % rad/s
    s.rpm = omega * 60 / (2 * pi);
    s.rpmSd = cfg.modelSd * s.rpm;
    if S > cfg.sRange(2) || S < cfg.sRange(1), s.label = 'outside the measured range';
    elseif x(7) >= 0, s.label = 'topspin';
    else, s.label = 'slice'; end
end
end
