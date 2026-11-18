% tv.events.bounceKind: one camera behind a baseline tells a ball bounced by the server from a
% bounce in play, and drops bounces on the next court (Chris, 18 Nov)
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
c = tv.court.constants();
cam = tv.camera.make(cams(1).lens, [-c.halfLength - 4.3, 0, 2.9], 0, -8, 0);
box = tv.court.interest();
fps = 60;
% the far server bounces the ball twice behind the far baseline: 1 m down and up, 0.6 s apart
t = (0:1/fps:1.4)';
z = 0.033 + abs(1.0 * cos(pi * t / 0.6));                       % on the ground at t = 0.3 and 0.9
A = [12.3 + 0 * t, 1 + 0.05 * sin(3 * t), z];
% a shot from the far baseline lands on the near side 1 s later and goes on
t2 = (0:1/fps:1.3)';  x2 = 11 - 17 * t2;  z2 = 0.033 + abs(1.2 + 3.7 * t2 - 4.9 * t2 .^ 2);
Bp = [x2, 1 + 0 * t2, z2];
pa = tv.camera.project(cam, A);  pb = tv.camera.project(cam, Bp);
P = [round(t * fps), pa; 200 + round(t2 * fps), pb];
[~, iLand] = min(z2);
mk = @(f, p, g) struct('frame', f, 'u', p(1), 'v', p(2), 'x', g(1), 'y', g(2));
B = [mk(18, pa(19, :), A(19, :)), mk(54, pa(55, :), A(55, :)), mk(200 + iLand - 1, pb(iLand, :), Bp(iLand, :)), ...
     mk(400, [900 500], [3, -11]), mk(500, [900 200], [40, -12])];

%% bounced on the spot twice: a dribble; the shot that came the length of the court: in play
[kind, came] = tv.events.bounceKind(cam, B, P, fps, box);
assert(strcmp(kind{1}, 'dribble') && strcmp(kind{2}, 'dribble'), strjoin(kind, ' '));
assert(came(2) < 1.5, sprintf('the bounced ball came %.1f m', came(2)));
assert(strcmp(kind{3}, 'play') && came(3) > 2.2, sprintf('%s, came %.1f m', kind{3}, came(3)));

%% a bounce on the next court is off the court, whatever came before it
kind = tv.events.bounceKind(cam, B, P, fps, box);
assert(strcmp(kind{4}, 'off'), kind{4});
% ... and a turn whose sight line reaches the ground far behind the court was in the air (a hit)
assert(strcmp(kind{5}, 'air'), kind{5});

%% one bounce on the spot with nothing like it nearby stays 'spot' (not enough to call a dribble)
kind = tv.events.bounceKind(cam, B(1), P, fps, box);
assert(strcmp(kind{1}, 'spot'), kind{1});
