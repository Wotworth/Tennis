% tv.track.dropAtPlayer: racquet tracks go, the ball hit away from a player stays
P.frames = (0:5:60)';
P.boxes = repmat({[100 100 200 300]}, numel(P.frames), 1);     % one player, still
f = (1:60)';
racquet = struct('frames', f, 'uv', [150 + 30 * sin(f / 5), 180 + 20 * cos(f / 5)], 'area', ones(60, 1), 'id', 1);
ball = struct('frames', f, 'uv', [180 + 8 * f, 150 - 2 * f], 'area', ones(60, 1), 'id', 2);   % leaves the player
far = struct('frames', f, 'uv', [500 + f, 50 + f], 'area', ones(60, 1), 'id', 3);
T = [racquet, ball, far];

%% a track that stays with the player is dropped; the ball leaving it and one far away are kept
[kept, gone] = tv.track.dropAtPlayer(T, P);
assert(isequal(gone, [true false false]), mat2str(gone));
assert(isequal([kept.id], [2 3]));

%% a track between sample frames, or with no player there, is kept
short = struct('frames', (6:9)', 'uv', repmat([150 200], 4, 1), 'area', ones(4, 1), 'id', 4);
[~, gone] = tv.track.dropAtPlayer(short, P);
assert(~gone);
Q = P;  Q.boxes = repmat({zeros(0, 4)}, numel(P.frames), 1);
[~, gone] = tv.track.dropAtPlayer(T, Q);
assert(~any(gone));

%% share: a track inside the player at 3 of its 4 sample frames goes only when share <= 0.75
t = struct('frames', (1:20)', 'uv', [150 * ones(15, 1), 200 * ones(15, 1); 400 * ones(5, 1), 200 * ones(5, 1)], 'area', ones(20, 1), 'id', 5);
[~, g1] = tv.track.dropAtPlayer(t, P);
[~, g2] = tv.track.dropAtPlayer(t, P, 0.75);
assert(~g1 && g2);
