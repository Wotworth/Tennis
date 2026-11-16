function others = planNeighbours(sc, truth, cams)
%PLANNEIGHBOURS  Everything on the courts next to Chris's (TV-ADJ-07), on truth's time base.
%   others.balls: struct array kind, ballP (N-by-3 over truth.T, NaN when absent)
%     'neighbour'  each neighbouring court's ball in play
%     'crossing'   a neighbour's ball passing right behind Chris's ball in camera 1
%     'rolling'    a stray rolling from the next court onto Chris's
%   others.players: struct array court, look (index into sc.otherLooks), way [t x y]
c = tv.court.constants();
T = truth.T;
others.balls = struct('kind', {}, 'ballP', {});
others.players = struct('court', {}, 'look', {}, 'way', {});
look = 0;
for k = 1:numel(sc.neighbourCourts)
    s = sc;  s.rallies = sc.neighbourRallies;  s.staticBall = [NaN NaN NaN];
    nt = tv.synth.planSession(s);
    mir = (-1)^k;                                       % mirror one court end to end
    B = nt.ballP;  B(:, 1) = mir * B(:, 1);  B(:, 2) = B(:, 2) + sc.neighbourCourts(k);
    others.balls(end+1) = struct('kind', 'neighbour', 'ballP', B);
    for p = 1:numel(nt.players)
        w = nt.players{p};  w(:, 2) = mir * w(:, 2);  w(:, 3) = w(:, 3) + sc.neighbourCourts(k);
        look = look + 1;
        others.players(end+1) = struct('court', k, 'look', look, 'way', w);
    end
end
% the neighbour by the shared sideline (far side), walking slowly along it
tw = (0:2:sc.duration)';
others.players(end+1) = struct('court', 0, 'look', numel(sc.otherLooks), ...
    'way', [tw, -6 + 8 * sin(tw / 7), sc.sidelineY + 0.3 * sin(tw / 3)]);
% crossing: a moment in the chosen rally when Chris's ball is in flight between 1.8
% and 3.2 m up; the point on camera 1's sight line through it at the given height,
% beyond Chris's court of interest, is where the neighbour's ball passes, then
cam = cams(1);
box = tv.court.interest(struct());
R = truth.rallies(sc.crossing.rally);
cand = find(T > R.start + 0.5 & T < R.stop - 0.5);
best = [];
for i = cand(1:10:end)'
    P = truth.ballP(i, :);
    if any(isnan(P)) || P(3) < 1.8 || P(3) > cam.pos(3) - 0.3, continue; end
    s = (cam.pos(3) - sc.crossing.height) / (cam.pos(3) - P(3));
    Q = cam.pos + s * (P - cam.pos);
    if Q(2) > box.y(2) + 1.5 && Q(2) < max(sc.neighbourCourts) + c.halfDoubles && abs(Q(1)) < c.halfLength
        best = [i, Q];  break
    end
end
if ~isempty(best)
    tau = T - T(best(1));
    B = best(2:4) + [12 * tau, 0 * tau, 2 * tau - 4.905 * tau.^2];
    B(tau < -0.3 | tau > 0.4, :) = NaN;
    others.balls(end+1) = struct('kind', 'crossing', 'ballP', B);
end
% a stray ball rolling from the next court onto Chris's, then lying there
r = sc.roll;
y = r.from - r.speed * (T - r.start);
y = max(y, r.to);
B = [r.x + 0 * T, y, c.ballRadius + 0 * T];
B(T < r.start, :) = NaN;
others.balls(end+1) = struct('kind', 'rolling', 'ballP', B);
end
