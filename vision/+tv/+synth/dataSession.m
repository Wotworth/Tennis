function S = dataSession(seed, opts)
%DATASESSION  A long synthetic session at the level of the pipeline's outputs (preview data).
%   For design previews: a 90-minute singles session of about 400 shots,
%   every shot flown with the full flight model (gravity, drag, Magnus,
%   wind), written in the same shapes the pipeline writes (shots, rallies,
%   trajectories, session) plus Fitbit-style heart rate. No video is
%   rendered (that would take hours); it is SYNTHETIC and labelled so.
%   Shot types are forehand/backhand/serve/volley as PH-5 will classify them.
%   S.shots, S.rallies, S.trajectories, S.session, S.hr, S.truthPlayers.
if nargin < 1, seed = 11; end
if nargin < 2, opts = struct(); end
d = struct('minutes', 90, 'targetShots', 410, 'dt', 0.01, 'tempC', 17, 'relHumidity', 0.6, ...
           'pressurePa', 101200, 'wind', [1.5 -0.8 0], 'startUtc', '2026-11-14T15:00:00.000Z');
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
tv.util.seed(seed);
c = tv.court.constants();
air = tv.physics.defaultParams();
air.rho = tv.air.density(opts.tempC, opts.relHumidity, opts.pressurePa);
air.wind = opts.wind;
T = 0;  shots = [];  rallies = [];  trajs = [];  rIdx = 0;
chrisEnd = -1;                                  % Chris starts at the -x end
game = 0;  pointInGame = 0;
while T < opts.minutes * 60 - 60 && numel(shots) < opts.targetShots
    rIdx = rIdx + 1;
    pointInGame = pointInGame + 1;
    if pointInGame > 6, pointInGame = 1; game = game + 1;
        if mod(game, 2) == 1, chrisEnd = -chrisEnd; T = T + 90; end   % changeover
    end
    server = 1 + mod(game, 2);                  % 1 Chris, 2 opponent
    ends = [chrisEnd, -chrisEnd];
    side = 2 * mod(pointInGame, 2) - 1;         % deuce / ad
    tStart = T + 5 + 10 * rand();
    t = tStart + 1.5;
    rally = [];
    hitter = server;
    p0 = [ends(server) * 11.95, -side * 0.8 * ends(server), 2.75];
    nShots = 0;  ending = 'winner';  isServe = true;  second = false;
    while true
        nShots = nShots + 1;
        [kind, target, speed, CL, spinDir] = planShot(hitter, isServe, second, ends, side, c);
        q = air;  q.CL = CL;  q.CD = 0.507 + 0.024 * randn();
        dirH = [target - p0(1:2), 0];  dirH = dirH / norm(dirH);
        ax = cross([0 0 1], dirH) * spinDir;
        if CL > 0, q.spinAxis = ax / norm(ax); end
        v0 = tv.synth.aimAt(p0, target, speed, q);
        [tt, P, V] = tv.physics.simulate(p0, v0, q, 4, opts.dt, c.ballRadius);
        hb = tv.physics.groundHit(P);
        q0 = q;  q0.CL = 0;
        [~, P0] = tv.physics.simulate(p0, v0, q0, 4, opts.dt, c.ballRadius);
        h0 = tv.physics.groundHit(P0);
        xc = find(sign(P(1:end-1,1)) ~= sign(P(2:end,1)), 1);
        clear0 = NaN;
        if ~isempty(xc)
            pc = P(xc, :);  clear0 = pc(3) - c.ballRadius - tv.court.netHeight(pc(2));
        end
        net = ~isnan(clear0) && clear0 < 0;
        m = struct();
        m.rally = rIdx;  m.index = nShots;  m.t = t;
        m.hitter = ifelse(hitter == 1, 'Chris', 'Player B');  m.hitterTrack = hitter;
        m.type = kind;  m.isServe = isServe;
        m.contact = p0;  m.speedContact = norm(v0);
        m.launchDeg = atan2d(v0(3), norm(v0(1:2)));  m.directionDeg = atan2d(v0(2), abs(v0(1)));
        m.netClearance = clear0;  m.apex = max(P(:, 3));  m.flightTime = tt(end);
        m.bounce = hb(1:2);  m.speedBounce = norm(V(end, :));
        far = abs(hb(1) - p0(1));
        m.bounceSd = 0.012 + 0.0012 * far;
        m.depth = c.halfLength - abs(hb(1));
        [m.call, m.margin] = tv.metrics.lineCall(hb(1:2), m.bounceSd, isServe, sign(p0(2)), -ends(hitter), struct('lines', 'singles'));
        if net, m.call = 'net'; m.bounce = [NaN NaN]; m.depth = NaN; end
        m.spinEffect = (hb(1:2) - h0(1:2)) * dirH(1:2)';
        m.spinEffectNet = NaN;
        sp = tv.metrics.spin([p0 v0 spinDir * CL 0 q.CD], air, []);
        m.spinTop = sp.top;  m.spinSide = sp.side;  m.CL = sp.CL;  m.rpm = sp.rpm;
        m.rpmSd = sqrt(sp.rpmSd^2 + (0.08 * sp.rpm)^2);  m.spinLabel = sp.label;
        vb = tv.physics.bounce(V(end, :), air);
        m.kickAngleDeg = atan2d(vb(3), norm(vb(1:2)));  m.speedAfter = norm(vb);  m.speedRatio = m.speedAfter / m.speedBounce;
        m.CD = q.CD;  m.fitRmsPx = 0.3 + 0.3 * rand();  m.confidence = 0.85 + 0.14 * rand();
        rally = [rally; m]; %#ok<AGROW>
        trajs = [trajs; struct('rally', rIdx, 'shot', nShots, 't0', t, 'dt', opts.dt, ...
            'xyz', round(P * 1000) / 1000, 'noSpin', round(P0 * 1000) / 1000)]; %#ok<AGROW>
        t = t + tt(end);
        if net, ending = 'net'; break; end
        if ~strcmp(m.call, 'in')
            if isServe && ~second, second = true; p0 = [ends(server) * 11.95, -side * 0.8 * ends(server), 2.7]; t = t + 3; nShots = nShots; continue; end
            ending = 'out'; break
        end
        % the other player returns it, or it is a winner
        if nShots >= 2 && rand() < 0.07, ending = 'winner'; t = t + 1; break; end
        hitter = 3 - hitter;  isServe = false;  second = false;
        back = abs(hb(1)) + 1.2 + 1.5 * rand();
        p0 = [ends(hitter) * min(back, 13.5), hb(2) * 0.8 + 0.4 * randn(), 0.7 + 0.5 * rand()];
        if rand() < 0.06, p0(1) = ends(hitter) * (3 + 2 * rand()); p0(3) = 1.3; end   % at the net: volley
        t = t + 0.45 + 0.3 * rand();
    end
    shots = [shots; rally]; %#ok<AGROW>
    rallies = [rallies; struct('index', rIdx, 'start', tStart, 'stop', t + 2, 'shots', numel(rally), ...
        'duration', t - rally(1).t, 'ending', ending, 'fastest', max([rally.speedContact]))]; %#ok<AGROW>
    T = t + 2 + 36 + 30 * rand();                % pick up the ball, walk back
end
S.shots = shots;  S.rallies = rallies;  S.trajectories = trajs;
S.session = struct('synthetic', true, 'startUtc', opts.startUtc, ...
    'air', struct('rho', air.rho, 'wind', air.wind(1:2), 'sessionCD', median([shots.CD]), 'tempC', opts.tempC), ...
    'crossing', struct('minDeg', 41.2, 'thresholdDeg', 20, 'low', {{}}, 'text', 'Camera sight lines cross at 41 deg or more everywhere on court.'), ...
    'identity', struct('chrisTrack', 0, 'confidence', [0.84 0.84], 'question', true), ...
    'counts', struct('rallies', numel(rallies), 'shots', numel(shots)));
S.hr = fitbitHeartRate(rallies, opts.minutes * 60);
end

function [kind, target, speed, CL, spinDir] = planShot(hitter, isServe, second, ends, side, c)
% plausible club-level targets and speeds (m/s), with spin
dir = -ends(hitter);                            % toward the other end
chris = hitter == 1;
if isServe
    kind = 'serve';
    target = [dir * (4.6 + 1.4 * rand()), side * ends(hitter) * (0.4 + 3.4 * rand())];   % the diagonal box
    if second
        speed = (chris * 36 + ~chris * 33) + 2.5 * randn();  CL = 0.12 + 0.03 * randn();
    else
        speed = (chris * 48 + ~chris * 44) + 3 * randn();    CL = 0.04 + 0.02 * rand();
        if rand() < 0.35, target(1) = dir * (c.serviceLine + 0.1 + 0.6 * rand()); end   % fault: long
    end
    spinDir = 1;
    return
end
fh = rand() < 0.58;
kind = ifelse(fh, 'forehand', 'backhand');
deep = c.halfLength - 2.4 - 1.6 * abs(randn());
if rand() < 0.05, deep = c.halfLength + 0.15 + 0.9 * rand(); end          % long
target = [dir * deep, (2 * rand() - 1) * 3.6];
if rand() < 0.02, target(2) = sign(target(2)) * (c.halfSingles + 0.1 + 0.5 * rand()); end   % wide
speed = (fh * 29.5 + ~fh * 26) * (chris * 1.0 + ~chris * 0.94) + 2.6 * randn();
CL = fh * (0.085 + 0.03 * randn()) + ~fh * (0.065 + 0.025 * randn());
spinDir = 1;
if ~fh && rand() < 0.22, spinDir = -1; CL = 0.07 + 0.02 * randn(); speed = speed * 0.8; end   % slice
CL = max(0.01, CL);
end

function hr = fitbitHeartRate(rallies, total)
% Fitbit-style: a reading every 1-5 s, rising with effort, slowly drifting up
% with fatigue; two dropouts longer than a minute (watch lost contact)
t = 0;  bpm = 92;  hr = struct('t', {}, 'bpm', {});
gaps = [1500 1590; 3900 3995];
while t < total
    inRally = any(t >= [rallies.start] & t <= [rallies.stop]);
    target = 118 + 18 * t / total + inRally * (28 + 6 * rand());
    if t < 300, target = 100 + 0.06 * t; end
    bpm = bpm + 0.18 * (target - bpm) + 1.5 * randn();
    if ~any(t >= gaps(:, 1) & t <= gaps(:, 2))
        hr(end+1) = struct('t', round(t * 10) / 10, 'bpm', round(bpm)); %#ok<AGROW>
    end
    t = t + 1 + 4 * rand();
end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
