% tv.events.pointsFromTracks: points from the ball's tracks; a server's dribble starts a new
% point, flickers don't bridge points, and a stretch with no bounce in play is not a point
mk = @(f) struct('frames', f(:));
fps = 60;
% point 1: frames 0-600; the server bounces the ball at 700 and 740 (tracked 660-780);
% point 2 (its serve) from 800 to 1300; a flicker at 1420; a ball rolled back 1600-1800 (5 s after the point)
tracks = {[mk(0:600), mk(660:780), mk(800:1300), mk(1420:1430), mk(1600:1800)]};
b = @(f, k) struct('frame', f, 'kind', k);
bounces = [b(200, 'play'), b(450, 'play'), b(700, 'dribble'), b(740, 'dribble'), b(900, 'play'), b(1700, 'spot')];

%% two points, the second starting after the dribble; the rolled ball is not a point
P = tv.events.pointsFromTracks(tracks, bounces, fps);
assert(size(P, 1) == 2, sprintf('%d points', size(P, 1)));
assert(P(1, 1) == 0 && P(1, 2) <= 700 - 30, mat2str(P(1, :)));
assert(P(2, 1) >= 740 + 30 && P(2, 2) == 1300, mat2str(P(2, :)));

%% without bounce kinds (older runs): spans joined by the gap alone
P = tv.events.pointsFromTracks(tracks, struct('frame', {}), fps);
assert(size(P, 1) == 2 && P(1, 1) == 0 && P(1, 2) == 1300 && P(2, 1) == 1600, mat2str(P));
