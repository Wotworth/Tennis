function [sc, truth] = tuesdayClip(name, M, size_)
%TUESDAYCLIP  One of Tuesday's clips as a synthetic scenario (Chris, 22 Nov: the dress rehearsal).
%   [sc, truth] = tv.synth.tuesdayClip('clip1', M)      M: the measurements (groundtruth JSON)
%   [sc, truth] = tv.synth.tuesdayClip('clip2', M, 'small')   960 x 540 for a quick local run
%   Tuesday's set-up: Linear lens, both cameras on one side fence 2.5 m beyond each baseline, 4 m out,
%   3.5 m up, 4K at 240 frames a second (the default 'camera' size; ball drawn at its true size).
%   Every clip opens, as the checklist says, with one ball bounced once in view of both cameras, then:
%     clip1  the six still balls of M.stillBalls lying where M puts them (for the whole clip)
%     clip2  a drop from M.drops.releaseHeightM at M's first drop spot, bouncing until it settles
%     clip3  a toss from 2.5 m that lands on M's first target cross
%     clip4  one machine feed from M.machine's position, topspin, landing deep on the near side
%   The clips are short (1.6 to 3.6 s) so the whole chain can run in CI; their structure is Tuesday's.
%   truth.ballP is the one moving ball; truth.shots lists hits and bounces (for the sound).
if nargin < 3, size_ = 'camera'; end
c = tv.court.constants();
sc = tv.synth.defaultScenario();
sc.lensName = 'Linear';  sc.mountX = c.halfLength + 2.5;  sc.standoff = 4;  sc.mountHeight = 3.5;
sc.fps = 240000 / 1001;  sc.codec = 'hevc';  sc.lrv = true;  sc.recordStart = [0, -0.2185];
if strcmp(size_, 'camera'), sc.frameSize = [3840 2160];  sc.ballDrawScale = 1;  sc.crf = 24;
else, sc.frameSize = [960 540];  sc.ballDrawScale = 4; end
sc.rallies = sc.rallies([]);  sc.staticBall = NaN(1, 3);
sc.fileNumber = 100 + str2double(name(end));
air = tv.physics.defaultParams();  air.rho = tv.air.density(sc.weather.tempC, sc.weather.relHumidity, sc.weather.pressurePa);
dt = 1e-3;
T = (0:dt:6)';  B = NaN(numel(T), 3);  shots = [];
% the opening bounce: dropped from 1.2 m by the near service line, centre
[B, shots] = drop(B, shots, T, 0.25, [-6.4, -0.8, 1.2], air, 1);   % then taken away (gone by 1.5 s)
switch name
    case 'clip1'
        sb = M.stillBalls.balls;  if iscell(sb), sb = [sb{:}]; end
        sc.staticBall = [[sb.x]', [sb.y]', [sb.z]'];
        sc.duration = 1.6;
    case 'clip2'
        sp = M.drops.spots;  if iscell(sp), sp = [sp{:}]; end
        [B, shots] = drop(B, shots, T, 1.6, [sp(1).x, sp(1).y, M.drops.releaseHeightM], air, 3);
        sc.duration = 3.8;
    case 'clip3'
        sp = M.targets.spots;  if iscell(sp), sp = [sp{:}]; end
        from = [sp(1).x - 2.5, sp(1).y, 1.2];  q = air;  q.CL = 0;  q.spinAxis = [0 1 0];
        v0 = tv.synth.aimAt(from, [sp(1).x, sp(1).y], 7, q);
        [B, shots] = flight(B, shots, T, 1.6, from, v0, q, 1);
        sc.duration = 3.1;
    case 'clip4'
        ms = M.machine;  if iscell(ms), ms = [ms{:}]; end
        from = [ms(1).position.x, ms(1).position.y, 1.0];
        q = air;  q.CL = 0.12;  v = [-1 0 0];  ax = cross(v, [0 0 1]);  q.spinAxis = -ax / norm(ax);
        v0 = tv.synth.aimAt(from, [-8.5, 0.6], 22, q);
        [B, shots] = flight(B, shots, T, 1.6, from, v0, q, 1);
        sc.duration = 3.5;
end
truth.T = T;  truth.ballP = B;  truth.shots = shots;  truth.segments = [];  truth.rallies = [];
truth.players = {[0, -13.5, -3.5; 10, -13.5, -3.5], [0, -13.5, 3.5; 10, -13.5, 3.5]};   % both behind the near baseline
truth.air = air;  truth.staticBall = sc.staticBall;
end

function [B, shots] = drop(B, shots, T, t0, p0, air, nBounces)
% let go from p0 at t0 (no throw), with drag; bounces until nBounces, then gone
q = air;  q.CL = 0;  q.spinAxis = [0 1 0];
[B, shots] = flight(B, shots, T, t0, p0, [0 0 0], q, nBounces);
end

function [B, shots] = flight(B, shots, T, t0, p0, v0, q, nBounces)
% a flight from p0 with v0 at t0 and its bounces, written into B (the ball's path on grid T)
c = tv.court.constants();
s = struct('tHit', t0, 'pHit', p0, 'tBounce', NaN, 'pBounce', [NaN NaN NaN]);
p = p0;  v = v0;  t = t0;
for b = 0:nBounces
    [tt, P, V] = tv.physics.simulate(p, v, q, 3, 1e-3, c.ballRadius);
    i = round((t + tt) / (T(2) - T(1))) + 1;  ok = i >= 1 & i <= numel(T);
    B(i(ok), :) = P(ok, :);
    t = t + tt(end);  p = [P(end, 1:2), c.ballRadius];  v = tv.physics.bounce(V(end, :), q);
    if b == 0, s.tBounce = t;  s.pBounce = p; end
    if norm(v) < 0.5, break; end
end
shots = [shots; s];
end
