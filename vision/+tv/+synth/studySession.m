function S = studySession(seed, opts)
%STUDYSESSION  A 90-minute singles session for the fit study: ball truth only, no video (TV-TST-01).
%   Every flight is flown with tv.physics.truthFlight, which differs from the
%   fitter's model on purpose (spin decay, C_L following the spin parameter
%   with per-shot scatter, per-shot C_D, wind gusts, ode45). Rallies are
%   continuous: toss, serve, bounce, the flight after the bounce, the next
%   contact, and so on, including half-volleys (hit 0.12-0.25 s after the
%   bounce), volleys (hit before the bounce), net balls and winners.
%   S.shots      one row per shot with the answers (truth times = camera 1's
%                clock, which is also session time when its offset and
%                drift are 0, as in tv.synth.defaultScenario)
%   S.pieces     per rally: struct array of flights (t, P) at 1 ms
%   S.windows    rally windows [start stop], s
%   S.air        mean air (rho, wind) and S.gust (the gusts)
%   SYNTHETIC: shot plans from tv.synth.planShot.
if nargin < 1, seed = 7; end
if nargin < 2, opts = struct(); end
d = struct('minutes', 90, 'targetShots', 400, 'tempC', 17, 'relHumidity', 0.6, 'pressurePa', 101200, ...
           'wind', [1.5 -0.8 0], 'gustAmp', 0.6, 'spinTau', 5, 'clScatter', 0.15, 'cdSd', 0.024, ...
           'halfVolley', 0.05, 'volley', 0.06, 'winner', 0.15);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
tv.util.seed(seed);
c = tv.court.constants();
air = tv.physics.defaultParams();
air.rho = tv.air.density(opts.tempC, opts.relHumidity, opts.pressurePa);
air.wind = opts.wind;
gust = struct('periods', [4 11 27], 'amp', opts.gustAmp * [1 1 1], 'phase', 2 * pi * rand(3, 2));
if opts.gustAmp == 0, gust = []; end
base = air;  base.gust = gust;  base.spinTau = opts.spinTau;  base.clScale = 1;  base.CL0 = 0;
T = 20;  shots = [];  pieces = {};  windows = zeros(0, 2);
chrisEnd = -1;  game = 0;  pointInGame = 0;  rIdx = 0;
while T < opts.minutes * 60 - 60 && numel(shots) < opts.targetShots
    rIdx = rIdx + 1;  pointInGame = pointInGame + 1;
    if pointInGame > 6, pointInGame = 1; game = game + 1;
        if mod(game, 2) == 1, chrisEnd = -chrisEnd; T = T + 90; end
    end
    server = 1 + mod(game, 2);  ends = [chrisEnd, -chrisEnd];
    side = 2 * mod(pointInGame, 2) - 1;
    fl = struct('t', {}, 'P', {});
    t = T;  second = false;  hitter = server;  isServe = true;  idx = 0;
    [p0, t, fl] = toss(ends(server), side, t, fl);
    while true
        idx = idx + 1;
        [kind, target, speed, CL, spinDir] = tv.synth.planShot(hitter, isServe, second, ends, side, c);
        dirH = [target - p0(1:2), 0];  dirH = dirH / norm(dirH);
        ax = cross([0 0 1], dirH) * spinDir;  ax = ax / norm(ax);
        qa = air;  qa.CL = CL;  qa.spinAxis = ax;
        v0 = tv.synth.aimAt(p0, target, speed, qa);              % aimed with the fitter's model
        q = base;  q.CL0 = CL;  q.spinAxis = ax;  q.t0 = t;
        q.CD = 0.507 + opts.cdSd * randn();  q.clScale = max(0.5, 1 + opts.clScatter * randn());
        [tt, P, V, info] = tv.physics.truthFlight(p0, v0, q, 4, c.ballRadius);
        s = struct('rally', rIdx, 'index', idx, 'tHit', t, 'pHit', p0, 'vHit', v0, 'speedHit', norm(v0), ...
            'hitter', hitter, 'isServe', isServe, 'kind', kind, 'result', '', 'tBounce', NaN, ...
            'pBounce', [NaN NaN NaN], 'spinEffect', NaN, 'netClearance', NaN, 'rpm0', info.rpm0, ...
            'CL0', CL * q.clScale, 'CLnom', CL, 'CD', q.CD, 'spinDir', spinDir, 'toNextHit', NaN, 'shortFlight', false);
        % the net
        xc = find(sign(P(1:end-1, 1)) ~= sign(P(2:end, 1)), 1);
        if ~isempty(xc)
            f = P(xc, 1) / (P(xc, 1) - P(xc + 1, 1));
            pc = P(xc, :) + f * (P(xc + 1, :) - P(xc, :));
            s.netClearance = pc(3) - c.ballRadius - tv.court.netHeight(pc(2));
            if s.netClearance < 0
                fl(end+1) = struct('t', t + tt(1:xc), 'P', P(1:xc, :)); %#ok<AGROW>
                qd = base;  qd.CD = q.CD;  qd.t0 = t + tt(xc);
                [t2, P2] = tv.physics.truthFlight([pc(1) - sign(v0(1)) * 0.05, pc(2), pc(3)], [-0.1 * v0(1), 0, 0], qd, 2, c.ballRadius);
                fl(end+1) = struct('t', t + tt(xc) + t2, 'P', P2); %#ok<AGROW>
                s.result = 'net';  shots = [shots; s]; %#ok<AGROW>
                t = t + tt(xc) + t2(end);
                break
            end
        end
        % a volley: the other player takes it out of the air
        if ~isServe && rand() < opts.volley
            xv = ends(3 - hitter) * (3 + 2 * rand());
            iv = find(sign(ends(3 - hitter)) * (P(:, 1) - xv) > 0 & P(:, 3) > 0.4 & P(:, 3) < 2.0, 1);
            if ~isempty(iv)
                fl(end+1) = struct('t', t + tt(1:iv), 'P', P(1:iv, :)); %#ok<AGROW>
                s.result = 'volley';  shots = [shots; s]; %#ok<AGROW>
                p0 = P(iv, :);  t = t + tt(iv);  hitter = 3 - hitter;  isServe = false;  second = false;
                continue
            end
        end
        fl(end+1) = struct('t', t + tt, 'P', P); %#ok<AGROW>
        hb = P(end, :);  s.tBounce = t + tt(end);  s.pBounce = hb;
        q0 = q;  q0.CL0 = 0;
        [~, P0] = tv.physics.truthFlight(p0, v0, q0, 4, c.ballRadius);
        s.spinEffect = (hb(1:2) - P0(end, 1:2)) * dirH(1:2)';
        s.result = tv.metrics.lineCall(hb(1:2), 1e-4, isServe, sign(p0(2)), -ends(hitter), struct('lines', 'singles'));
        % after the bounce
        vb = tv.physics.bounce(V(end, :), air);
        qb = base;  qb.CD = q.CD;  qb.CL0 = 0.04;  qb.spinAxis = ax;  qb.t0 = s.tBounce;
        [tb, Pb] = tv.physics.truthFlight([hb(1:2), c.ballRadius + 1e-4], vb, qb, 2.5, c.ballRadius);
        t = s.tBounce;
        if ~strcmp(s.result, 'in') || rand() < opts.winner
            k = find(tb <= 0.8, 1, 'last');
            fl(end+1) = struct('t', t + tb(1:k), 'P', Pb(1:k, :)); %#ok<AGROW>
            shots = [shots; s]; %#ok<AGROW>
            t = t + tb(k);
            if strcmp(s.result, 'in') || ~isServe || second, break; end
            second = true;  t = t + 3;  [p0, t, fl] = toss(ends(server), side, t, fl);
            continue
        end
        if rand() < opts.halfVolley, dt = 0.12 + 0.13 * rand(); s.shortFlight = true;
        else, dt = 0.35 + 0.4 * rand(); end
        dt = min(dt, 0.85 * tb(end));
        k = find(tb <= dt, 1, 'last');
        fl(end+1) = struct('t', t + tb(1:k), 'P', Pb(1:k, :)); %#ok<AGROW>
        s.toNextHit = tb(k);
        shots = [shots; s]; %#ok<AGROW>
        p0 = Pb(k, :);  t = t + tb(k);
        hitter = 3 - hitter;  isServe = false;  second = false;
    end
    pieces{end+1, 1} = fl; %#ok<AGROW>
    windows(end+1, :) = [fl(1).t(1) - 1.5, t + 2]; %#ok<AGROW>
    T = t + 2 + 36 + 30 * rand();
end
S.shots = shots;  S.pieces = pieces;  S.windows = windows;  S.air = air;  S.gust = gust;  S.opts = opts;

    function [p, tOut, fl] = toss(e, sd, tIn, fl)
        % a slow vertical toss above the server; contact as it falls back through 2.75 m
        q1 = base;  q1.t0 = tIn;  q1.CD = 0.507;
        pT = [e * 11.95, -sd * 0.8 * e, 1.6];
        [t1, P1] = tv.physics.truthFlight(pT, [-e * 0.35, 0.05, 5.0], q1, 1.5);
        k1 = find(t1 > 0.3 & P1(:, 3) <= 2.75, 1);
        fl(end+1) = struct('t', tIn + t1(1:k1), 'P', P1(1:k1, :));
        p = P1(k1, :);  tOut = tIn + t1(k1);
    end
end
