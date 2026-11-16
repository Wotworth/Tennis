function truth = planSession(sc)
%PLANSESSION  Truth for a synthetic session: every ball flight, event and player path.
%   Simulates each rally of scenario sc (tv.synth.defaultScenario) at 1 ms.
%   Shots are aimed with the fitter's flight model but flown with the truth
%   model (tv.physics.truthFlight), so the test does not check the fit
%   against itself (Chris, 16 Nov). Times are truth seconds (= camera 1's clock).
%   truth.ballT, truth.ballP   the ball's centre (NaN while out of play)
%   truth.shots                one row per shot, with the answers the
%                              pipeline must recover
%   truth.players              waypoints [t x y] per player
c   = tv.court.constants();
prm = tv.physics.defaultParams();
prm.rho  = tv.air.density(sc.weather.tempC, sc.weather.relHumidity, sc.weather.pressurePa);
prm.wind = sc.wind;  prm.CD = sc.CD;
dt  = 1e-3;
T   = (0:dt:sc.duration)';
B   = nan(numel(T), 3);
shots = [];  segs = [];  rallies = [];
way = {zeros(0, 3), zeros(0, 3)};          % per player: [t x y]
ends = [-1 1];                             % player 1 at -x, player 2 at +x (rally 1)

for r = 1:numel(sc.rallies)
    R = sc.rallies(r);
    s = R.serverEnd;  srv = R.server;  rcv = 3 - srv;
    ends(srv) = s;  ends(rcv) = -s;
    t0 = R.start;
    % stand ready
    way{srv}(end+1, :) = [t0 - 1.5, s*12.2, -0.9];
    way{rcv}(end+1, :) = [t0 - 1.5, -s*12.0, 1.8];
    % toss (TV-EVT-05: a slow vertical toss above the server)
    pT = [s*11.95, -0.75, 1.6];  vT = [-s*0.35, 0.05, 5.0];
    q = prm;  q.CL = 0;
    [tt, P] = tv.physics.simulate(pT, vT, q, 1.5, dt);
    k = find(tt > 0.3 & P(:,3) <= 2.75, 1);
    addSeg(t0, tt(1:k), P(1:k, :), 'toss', 0);
    tHit = t0 + tt(k);  pHit = P(k, :);
    hitter = srv;
    for k = 1:size(R.shots, 1)
        [target, speed, CL, kind] = R.shots{k, :};
        way{hitter}(end+1, :) = [tHit, pHit(1) + ends(hitter)*0.35, pHit(2) - 0.7];
        q = prm;  q.CL = CL;
        if strcmp(kind, 'net')
            target = [-ends(hitter)*0.35, target(2)];  q.CL = 0.1;  kind = 'top';
        end
        dirH = [target(1) - pHit(1), target(2) - pHit(2)];  dirH = [dirH / norm(dirH), 0];
        ax = cross([0 0 1], dirH);
        if strcmp(kind, 'slice'), ax = -ax; end
        if strcmp(kind, 'flat') || CL == 0, q.CL = 0; end
        q.spinAxis = ax / max(norm(ax), eps);
        v0 = tv.synth.aimAt(pHit, target, speed, q);       % aimed with the fitter's model
        % flown with the truth model: per-shot drag and lift scatter (fixed, so the
        % scenario repeats), spin decay, lift following the spin parameter, gusts
        qt = prm;  qt.CL0 = q.CL;  qt.spinAxis = q.spinAxis;  qt.t0 = tHit;
        qt.CD = sc.CD + sc.CDsd * sin(1.7 * k + 3.1 * r);
        qt.clScale = 1 + sc.clScatter * cos(2.3 * k + 1.3 * r);
        qt.spinTau = sc.spinTau;  qt.gust = sc.gust;
        [tt, P, V] = tv.physics.truthFlight(pHit, v0, qt, 4, c.ballRadius);
        q.CD = qt.CD;  q.CL = q.CL * qt.clScale;
        % the net
        xc = find(sign(P(1:end-1,1)) ~= sign(P(2:end,1)), 1);
        netHit = false;  clearance = NaN;
        if ~isempty(xc)
            f = P(xc,1) / (P(xc,1) - P(xc+1,1));
            pc = P(xc,:) + f * (P(xc+1,:) - P(xc,:));
            clearance = pc(3) - c.ballRadius - tv.court.netHeight(pc(2));
            netHit = clearance < 0;
        end
        shot = struct('rally', r, 'index', k, 'hitter', hitter, 'isServe', k == 1, ...
            'tHit', tHit, 'pHit', pHit, 'vHit', v0, 'speedHit', norm(v0), 'CD', q.CD, ...
            'CL', q.CL, 'spinAxis', q.spinAxis, 'netClearance', clearance, ...
            'tBounce', NaN, 'pBounce', [NaN NaN NaN], 'speedBounce', NaN, ...
            'result', '', 'spinEffect', NaN);
        if netHit
            addSeg(tHit, tt(1:xc), P(1:xc, :), 'shot', k);
            % the ball drops dead at the net
            q0 = qt;  q0.CL0 = 0;  q0.t0 = tHit + tt(xc);
            [t2, P2] = tv.physics.truthFlight([pc(1) - sign(v0(1))*0.05, pc(2), pc(3)], [-0.1*v0(1), 0, 0], q0, 2, c.ballRadius);
            addSeg(tHit + tt(xc), t2, P2, 'dead', k);
            shot.result = 'net';
            shots = [shots; shot]; %#ok<AGROW>
            tEnd = tHit + tt(xc) + t2(end);
            break
        end
        hb = P(end, :);                                   % truthFlight ends at the touch
        addSeg(tHit, tt, P, 'shot', k);
        shot.tBounce = tHit + tt(end);                     % truthFlight ends exactly at the touch
        shot.pBounce = hb;  shot.speedBounce = norm(V(end, :));
        % spin effect (TV-SPN-01): the same launch with no lift, in the same truth air
        q0 = qt;  q0.CL0 = 0;
        [~, P0] = tv.physics.truthFlight(pHit, v0, q0, 4, c.ballRadius);
        h0 = P0(end, :);
        dH = dirH(1:2);
        shot.spinEffect = (hb(1:2) - h0(1:2)) * dH';     % negative: landed shorter
        if k == 1
            % the diagonal service box on the far side (the server stands at y < 0)
            inside = abs(hb(1)) <= c.serviceLine && sign(hb(1)) == -ends(srv) && ...
                     hb(2) >= 0 && hb(2) <= c.halfSingles;
        else
            inside = abs(hb(1)) <= c.halfLength && abs(hb(2)) <= c.halfSingles;
        end
        shot.result = ifelse(inside, 'in', 'out');
        % after the bounce
        vb = tv.physics.bounce(V(end, :), prm);
        qb = qt;  qb.CL0 = 0.5 * qt.CL0;  qb.t0 = shot.tBounce;
        [t2, P2] = tv.physics.truthFlight([hb(1:2), c.ballRadius + 1e-4], vb, qb, 3, c.ballRadius);
        nextHitter = 3 - hitter;
        last = k == size(R.shots, 1) || ~inside;
        if ~last
            xr = ends(nextHitter) * 11.9;
            j = find(abs(P2(:,1)) >= abs(xr) & sign(P2(:,1)) == sign(xr), 1);
            if isempty(j)
                [~, apex] = max(P2(:,3));
                j = apex - 1 + find(P2(apex:end, 3) <= 0.8, 1);
            end
            addSeg(shot.tBounce, t2(1:j), P2(1:j, :), 'bounce', k);
            tHit = shot.tBounce + t2(j);  pHit = P2(j, :);
            hitter = nextHitter;
            shots = [shots; shot]; %#ok<AGROW>
        else
            j = min(numel(t2), find(t2 >= 0.7, 1));
            addSeg(shot.tBounce, t2(1:j), P2(1:j, :), 'bounce', k);
            shots = [shots; shot]; %#ok<AGROW>
            tEnd = shot.tBounce + t2(j);
            break
        end
    end
    rallies = [rallies; struct('start', t0, 'stop', tEnd, 'server', srv)]; %#ok<AGROW>
    % after the point: stroll, then (between rallies) change ends past the net post
    for p = 1:2
        last = way{p}(end, :);
        way{p}(end+1, :) = [tEnd + 1.0, last(2) - ends(p)*0.0, last(3) * 0.5];
    end
    if r < numel(sc.rallies)
        tn = sc.rallies(r+1).start - 1.5;
        mid = (tEnd + 1.0 + tn) / 2;
        for p = 1:2
            stag = 0.25 * (p - 1.5);          % they pass each other at the post
            way{p}(end+1, :) = [mid + stag, 0.0, -c.postY - 0.6];
        end
    end
end

truth.T = T;  truth.ballP = B;  truth.shots = shots;  truth.segments = segs;
truth.rallies = rallies;  truth.players = way;  truth.air = prm;
truth.staticBall = sc.staticBall;

    function addSeg(t0, tt, P, kind, k)
        idx = round((t0 + tt) / dt) + 1;
        keep = idx >= 1 & idx <= numel(T);
        B(idx(keep), :) = P(keep, :);
        segs = [segs; struct('t0', t0, 't1', t0 + tt(end), 'kind', kind, 'shot', k)];
    end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
