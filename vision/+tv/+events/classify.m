function ev = classify(segs, air, opts)
%CLASSIFY  Events between a rally's flight segments: toss, hit, bounce, net (TV-EVT-01 to 05).
%   Where one segment ends and the next begins, both fitted paths are run to
%   the moment they come closest; that is where and when the event happened.
%   - bounce: there, near the ground (ball centre within 0.3 m), falling
%     before and rising after. Its point is solved from both sides at
%     ball-centre height 3.35 cm (TV-EVT-02).
%   - net: near x = 0 and the ball then slow (it dropped off the net), or the
%     last flight crosses x = 0 below the tape (TV-EVT-03).
%   - hit: anything else (a sudden change of speed or direction, TV-EVT-01).
%   - toss: a rally's first segment if it rises nearly straight up (TV-EVT-05).
%   Returns struct array ev: type, t, p (3D), segBefore, segAfter.
%   RETUNE(real footage): the 0.3 m, 6 m/s and 3 m/s limits.
if nargin < 3, opts = struct(); end
c = tv.court.constants();
ev = struct('type', {}, 't', {}, 'p', {}, 'segBefore', {}, 'segAfter', {});
n = numel(segs);
if n == 0, return; end
% toss
[~, V0] = tv.recon.segmentModel(segs(1).x, segs(1).t0, segs(1).t0, air);
if norm(V0(1:2)) < 3 && V0(3) > 0
    ev(end+1) = struct('type', 'toss', 't', segs(1).t0, 'p', segs(1).x(1:3), 'segBefore', 0, 'segAfter', 1);
end
for k = 1:n - 1
    a = segs(k);  b = segs(k + 1);
    tEndA = max(a.t);  tStartB = min(b.t);
    tt = linspace(tEndA - 0.01, tStartB + 0.01, 200)';
    Pa = tv.recon.segmentModel(a.x, a.t0, tt, air);
    Pb = extrapBack(b, tt, air);
    [~, i] = min(sum((Pa - Pb).^2, 2));
    tc = tt(i);  pc = (Pa(i, :) + Pb(i, :)) / 2;
    [~, Va] = tv.recon.segmentModel(a.x, a.t0, tc, air);
    [~, Vb] = tv.recon.segmentModel(b.x, b.t0, max(tc, b.t0), air);
    if pc(3) < 0.3 && Va(3) < 0 && Vb(3) > 0
        [tb, pb] = bouncePoint(a, b, air, c);
        ev(end+1) = struct('type', 'bounce', 't', tb, 'p', pb, 'segBefore', k, 'segAfter', k + 1); %#ok<AGROW>
    elseif abs(pc(1)) < 0.8 && norm(Vb) < 6
        ev(end+1) = struct('type', 'net', 't', tc, 'p', pc, 'segBefore', k, 'segAfter', k + 1); %#ok<AGROW>
    else
        ev(end+1) = struct('type', 'hit', 't', tc, 'p', pc, 'segBefore', k, 'segAfter', k + 1); %#ok<AGROW>
    end
end
% the last flight: does it bounce or hit the net soon after the cameras lose it?
z = segs(n);
tt = (max(z.t):0.002:max(z.t) + 0.4)';
Pz = tv.recon.segmentModel(z.x, z.t0, tt, air);
xc = find(sign(Pz(1:end-1, 1)) ~= sign(Pz(2:end, 1)), 1);
g  = find(Pz(:, 3) < c.ballRadius, 1);
if ~isempty(xc) && (isempty(g) || xc < g) && Pz(xc, 3) - c.ballRadius < tv.court.netHeight(Pz(xc, 2))
    ev(end+1) = struct('type', 'net', 't', tt(xc), 'p', Pz(xc, :), 'segBefore', n, 'segAfter', 0);
elseif ~isempty(g) && g > 1
    f = (Pz(g-1, 3) - c.ballRadius) / (Pz(g-1, 3) - Pz(g, 3));
    ev(end+1) = struct('type', 'bounce', 't', tt(g-1) + f * 0.002, 'p', Pz(g-1, :) + f * (Pz(g, :) - Pz(g-1, :)), ...
        'segBefore', n, 'segAfter', 0);
end
[~, o] = sort([ev.t]);  ev = ev(o);
end

function P = extrapBack(s, tt, air)
% the segment's path, run backwards before its first detection with a short
% straight-line-plus-gravity extrapolation
P = tv.recon.segmentModel(s.x, s.t0, max(tt, s.t0), air);
early = tt < s.t0;
if any(early)
    [p0, v0] = tv.recon.segmentModel(s.x, s.t0, s.t0, air);
    dt = tt(early) - s.t0;
    P(early, :) = p0 + dt .* v0 + 0.5 * dt.^2 .* [0 0 -air.g];
end
end

function [tb, pb] = bouncePoint(a, b, air, c)
% where the falling path reaches ball-centre height, and where the rising
% path left it; the bounce is their average (TV-EVT-02)
tt = (max(a.t) - 0.02:0.0005:max(a.t) + 0.05)';
Pa = tv.recon.segmentModel(a.x, a.t0, tt, air);
i = find(Pa(:, 3) < c.ballRadius, 1);
if isempty(i), [~, i] = min(Pa(:, 3)); end
i = max(i, 2);
f = (Pa(i-1, 3) - c.ballRadius) / (Pa(i-1, 3) - Pa(i, 3));
ta = tt(i-1) + f * 0.0005;  pa = Pa(i-1, :) + f * (Pa(i, :) - Pa(i-1, :));
[p0, v0] = tv.recon.segmentModel(b.x, b.t0, b.t0, air);
% solve p0z + vz*dt - g/2 dt^2 = r for the dt < 0 root
qa = -air.g / 2;  qb = v0(3);  qc = p0(3) - c.ballRadius;
dts = roots([qa qb qc]);  dts = real(dts(dts < 0.01 & dts > -0.1));
if isempty(dts), tb = ta; pb = pa; return; end
dt = max(dts);
pb2 = p0 + dt * v0 + 0.5 * dt^2 * [0 0 -air.g];
tb = (ta + b.t0 + dt) / 2;
pb = (pa + pb2) / 2;  pb(3) = c.ballRadius;
end
