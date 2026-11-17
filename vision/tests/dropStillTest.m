% Still tracks (footage test, 17 Nov): a ball lying by the fence jitters by a pixel and the
% tracker may hop to the ball beside it; it must go. A ball in flight, even a slow one seen
% far away, must stay.
rand('seed', 3);  randn('seed', 3);
n = 120;  f = (0:n-1)';
% a resting ball with 1 px jitter and one hop to a neighbouring ball; a slow ball in flight,
% 1.5 px/frame, with the same jitter
uv = [200 150] + randn(n, 2);
uv(61:end, 1) = uv(61:end, 1) + 12;           % the hop
rest = struct('frames', uint32(f), 'uv', uv, 'area', 20 * ones(n, 1), 'id', 1);
uv2 = [400 300] + [1.2 * f, -0.9 * f] + randn(n, 2);
fly = struct('frames', uint32(f), 'uv', uv2, 'area', 20 * ones(n, 1), 'id', 2);

%% The resting ball is dropped and the slow flight kept

[kept, still, rate] = tv.track.dropStill([rest, fly], 1.0, 15);
assert(isequal(still(:)', [true false]), mat2str(rate'))
assert(numel(kept) == 1 && kept(1).id == 2)
assert(rate(1) < 0.3 && abs(rate(2) - 1.5) < 0.2, mat2str(rate'))

%% Gaps in a track are allowed (movement per frame, not per detection)
g = fly;  keep = mod(f, 3) == 0;
g.frames = g.frames(keep);  g.uv = g.uv(keep, :);  g.area = g.area(keep);
[~, st] = tv.track.dropStill(g, 1.0, 15);
assert(~st)

%% A two-point track is judged on its end-to-end movement
two = struct('frames', uint32([0; 1]), 'uv', [0 0; 0.2 0], 'area', [20; 20], 'id', 3);
[~, st] = tv.track.dropStill(two, 1.0, 15);
assert(st)
