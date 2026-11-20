function m = shot(seg, segAfter, hitEv, bounceEv, netEv, air, cfg, players, playerInfo, isServe, serverSide)
%SHOT  Every metric of one shot (spec section 5, "Shot metrics").
%   seg: the flight after the hit; segAfter: the flight after its bounce (or
%   []); hitEv/bounceEv/netEv: events (or []); players: tracks from
%   tv.players.track. Times are session seconds, positions metres (court
%   frame), speeds m/s. The app converts to mph and feet (TV-ARCH-11).
%   RETUNE(real footage): the confidence formula (fit error and detections)
%   and the 2.5 m hitter limit.
c = tv.court.constants();
x = seg.x;
tHit = seg.t0;  pHit = x(1:3);
if ~isempty(hitEv), tHit = hitEv.t; pHit = hitEv.p; end
[~, vHit] = tv.recon.segmentModel(x, seg.t0, max(tHit, seg.t0), air);
m.t = tHit;
m.contact = pHit;
m.speedContact = norm(vHit);
m.launchDeg = atan2d(vHit(3), norm(vHit(1:2)));
m.directionDeg = atan2d(vHit(2), abs(vHit(1)));      % 0 = straight down the court
m.isServe = isServe;
m.type = shotType(isServe, pHit, segAfter);
% hitter: nearest tracked player at the hit, within 2.5 m (TV-PLY-09)
m.hitter = 'unknown';  m.hitterTrack = 0;
best = 2.5;
for k = 1:numel(players)
    tr = players(k);
    if tHit < tr.t(1) - 0.5 || tHit > tr.t(end) + 0.5, continue; end
    xy = [interp1(tr.t, tr.xy(:,1), tHit, 'linear', 'extrap'), interp1(tr.t, tr.xy(:,2), tHit, 'linear', 'extrap')];
    d = norm(xy - pHit(1:2));
    if d < best, best = d; m.hitterTrack = k; end
end
if m.hitterTrack > 0
    if m.hitterTrack == playerInfo.chris, m.hitter = 'Chris';
    else, m.hitter = sprintf('Player %c', 'A' + sum((1:m.hitterTrack - 1) ~= playerInfo.chris)); end
end
% path to the bounce
tEnd = max(seg.t) + 0.6;
if ~isempty(bounceEv), tEnd = bounceEv.t; end
tt = (tHit:0.001:tEnd)';
P = tv.recon.segmentModel(x, seg.t0, max(tt, seg.t0), air);
[m.apex, ~] = max(P(:, 3));
m.flightTime = tEnd - tHit;
% net clearance: the ball's bottom over the net, with the sag (TV-EVT-03)
m.netClearance = NaN;
i = find(sign(P(1:end-1, 1)) ~= sign(P(2:end, 1)), 1);
if ~isempty(i)
    f = P(i, 1) / (P(i, 1) - P(i+1, 1));
    pc = P(i, :) + f * (P(i+1, :) - P(i, :));
    m.netClearance = pc(3) - c.ballRadius - tv.court.netHeight(pc(2));
end
% bounce, depth, in/out with uncertainty (TV-EVT-04)
m.bounce = [NaN NaN];  m.bounceSd = NaN;  m.bounceSdFit = NaN;  m.speedBounce = NaN;  m.depth = NaN;
m.call = 'no bounce';  m.margin = NaN;
if ~isempty(netEv)
    m.call = 'net';
elseif ~isempty(bounceEv)
    m.bounce = bounceEv.p(1:2);
    [~, vb] = tv.recon.segmentModel(x, seg.t0, bounceEv.t, air);
    m.speedBounce = norm(vb);
    m.depth = c.halfLength - abs(m.bounce(1));
    me = modelErr(cfg);
    m.bounceSdFit = tv.metrics.bounceSd(seg, air, cfg);
    m.bounceSd = hypot(m.bounceSdFit, me.bounceM);     % 21 Nov: with the model-error term (line calls)
    [m.call, m.margin] = tv.metrics.lineCall(m.bounce, m.bounceSd, isServe, serverSide, -sign(pHit(1)), cfg);
end
% after the bounce: kick (rebound angle and speed ratio)
m.kickAngleDeg = NaN;  m.speedRatio = NaN;  m.speedAfter = NaN;
if ~isempty(segAfter) && ~isempty(bounceEv)
    [~, va] = tv.recon.segmentModel(segAfter.x, segAfter.t0, max(bounceEv.t, segAfter.t0), air);
    m.kickAngleDeg = atan2d(va(3), norm(va(1:2)));
    m.speedAfter = norm(va);
    m.speedRatio = m.speedAfter / m.speedBounce;
end
% spin effect (TV-SPN-01): the same launch with no lift
q = air;  q.CD = x(9);  q.CL = 0;
[~, P0] = tv.physics.simulate(x(1:3), x(4:6), q, 4, 1e-3, c.ballRadius);
h0 = tv.physics.groundHit(P0);
dirH = x(4:5) / norm(x(4:5));
m.spinEffect = NaN;  m.spinEffectNet = NaN;  m.spinCurve = NaN;  m.spinEffectSd = NaN;  m.spinCurveSd = NaN;
m.spinEffectSdFit = NaN;  m.spinCurveSdFit = NaN;  m.windLevel = '';  m.gustRatio = NaN;
if ~isempty(h0) && ~isempty(bounceEv)
    hb = segGround(x, seg.t0, air, c);
    m.spinEffect = (hb(1:2) - h0(1:2)) * dirH';           % negative: landed shorter
    % sideways: how far spin curved it, across the flight (Chris, 17 Nov: a slice serve curves;
    % it isn't backspin), positive to the left of the direction of flight
    m.spinCurve = (hb(1:2) - h0(1:2)) * [-dirH(2); dirH(1)];
end
% their uncertainty from the fit (Chris, 21 Nov): the curve tile shows only when the curve is
% clearly larger than this shot's own uncertainty, and never a direction the fit isn't sure of
[m.spinEffectSdFit, m.spinCurveSdFit] = effectSd(seg, air, c, m.spinEffect, m.spinCurve);
% 21 Nov (Chris, item 3): the fit's own uncertainty is 4 to 10 times too small; what the flight
% model leaves out is added (cfg.modelErr, measured from the shot study), and only that is used
me = forWind(modelErr(cfg), air);
m.windLevel = me.windLevel;  m.gustRatio = me.gustRatio;
m.spinEffectSd = sqrt(m.spinEffectSdFit ^ 2 + me.effectM ^ 2 + (me.effectFrac * m.spinEffect) ^ 2);
m.spinCurveSd = sqrt(m.spinCurveSdFit ^ 2 + me.curveM ^ 2 + (me.curveFrac * m.spinCurve) ^ 2);
i0 = find(sign(P0(1:end-1, 1)) ~= sign(P0(2:end, 1)), 1);
if ~isempty(i0) && ~isnan(m.netClearance)
    f = P0(i0, 1) / (P0(i0, 1) - P0(i0+1, 1));
    p0c = P0(i0, :) + f * (P0(i0+1, :) - P0(i0, :));
    m.spinEffectNet = m.netClearance - (p0c(3) - c.ballRadius - tv.court.netHeight(p0c(2)));
end
sp = tv.metrics.spin(x, air, []);
m.spinTop = sp.top;  m.spinSide = sp.side;  m.CL = sp.CL;  m.rpm = sp.rpm;  m.rpmSd = sp.rpmSd;  m.spinLabel = sp.label;
m.CD = x(9);
m.fitRmsPx = seg.rmsPx;
m.confidence = max(0, min(1, 1 - (seg.rmsPx - 0.5) / 1.5)) * min(1, min(seg.n) / 20);
end

function hb = segGround(x, t0, air, c)
q = air;  q.CD = x(9);
[e1, e2] = tv.recon.spinBasis(x(4:6));  a = x(7) * e1 + x(8) * e2;
q.CL = norm(a);  if q.CL > 0, q.spinAxis = a / q.CL; end
[~, P] = tv.physics.simulate(x(1:3), x(4:6), q, 4, 1e-3, c.ballRadius);
hb = tv.physics.groundHit(P);
if isempty(hb), hb = P(end, :); end
end

function me = modelErr(cfg)
% the model-error terms: from cfg (the pipeline passes cfg.modelErr), else the defaults
if isfield(cfg, 'modelErr'), me = cfg.modelErr; return; end
persistent d
if isempty(d), q = tv.pipeline.defaults(); d = q.modelErr; end
me = d;
end

function [sdE, sdC] = effectSd(seg, air, c, e0, c0)
% first-order propagation of the fit's covariance to the spin effect and the sideways curve
sdE = NaN;  sdC = NaN;
if ~isfinite(e0) || ~isfield(seg, 'cov') || any(~isfinite(seg.cov(:))), return; end
x = seg.x;  C = (seg.cov + seg.cov') / 2;
g = zeros(2, 9);
for j = 1:9
    h = max(1e-4, 0.05 * sqrt(max(C(j, j), 0)));
    xp = x;  xp(j) = xp(j) + h;
    v = effects(xp, seg.t0, air, c);
    if any(~isfinite(v)), return; end
    g(:, j) = (v - [e0; c0]) / h;
end
S = g * C * g';
sdE = sqrt(max(S(1, 1), 0));  sdC = sqrt(max(S(2, 2), 0));
end

function v = effects(x, t0, air, c)
% [spin effect; sideways curve] of parameters x, as computed above
v = [NaN; NaN];
q = air;  q.CD = x(9);  q.CL = 0;
[~, P0] = tv.physics.simulate(x(1:3), x(4:6), q, 4, 1e-3, c.ballRadius);
h0 = tv.physics.groundHit(P0);
if isempty(h0), return; end
dirH = x(4:5) / norm(x(4:5));
hb = segGround(x, t0, air, c);
v = [(hb(1:2) - h0(1:2)) * dirH'; (hb(1:2) - h0(1:2)) * [-dirH(2); dirH(1)]];
end

function t = shotType(isServe, p, segAfter)
% PH-5 adds forehand / backhand; here: serve, overhead (contact above 2.3 m), groundstroke
if isServe, t = 'serve';
elseif p(3) > 2.3, t = 'overhead';
else, t = 'groundstroke'; end
end

function me = forWind(me, air)
% the sideways-curve term between calm and the studied gusts, by the session's gusts (22 Nov, item 10):
% extra variance = calm^2 + r^2 (gusts^2 - calm^2), r = (gust - mean wind at 10 m) / gustRefMps, capped.
% Unknown gusts: the studied level (r = 1). me.windLevel: calm (r < 0.5), breezy (to 1), gusty (over 1).
me.gustRatio = 1;  me.windLevel = 'unknown';
if ~isfield(me, 'curveMCalm'), return; end
g = NaN;  if isfield(air, 'gustExcess10'), g = air.gustExcess10; end
if isfinite(g)
    me.gustRatio = min(g / me.gustRefMps, me.gustCap);
    if me.gustRatio < 0.5, me.windLevel = 'calm'; elseif me.gustRatio <= 1, me.windLevel = 'breezy'; else, me.windLevel = 'gusty'; end
end
r2 = me.gustRatio ^ 2;
me.curveM = sqrt(me.curveMCalm ^ 2 + r2 * (me.curveM ^ 2 - me.curveMCalm ^ 2));
me.curveFrac = sqrt(me.curveFracCalm ^ 2 + r2 * (me.curveFrac ^ 2 - me.curveFracCalm ^ 2));
end
