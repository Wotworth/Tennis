% tv.track.chains: the ball's path through confident detections, not a racquet's flicker
rand('seed', 5);
f = (1:40)';
ball = [f, 300 + 9 * f, 200 - 6 * f + 0.2 * f .^ 2, 0.9 * ones(40, 1), 4 * ones(40, 1), 9 * ones(40, 1)];
ball(12:15, :) = [];                                       % hidden behind a player for 4 frames
racquet = [f, 800 + 20 * sin(f), 500 + 20 * cos(f), 0.6 * ones(40, 1), 4 * ones(40, 1), 9 * ones(40, 1)];
racquet(rand(40, 1) < 0.5, 4) = 0.05;                      % only sometimes ball-like
noise = [randi(40, 60, 1), 1920 * rand(60, 1), 1080 * rand(60, 1), 0.02 * ones(60, 1), 4 * ones(60, 1), 9 * ones(60, 1)];
D = [ball; racquet; noise];

%% the ball's path is the best chain, across the gap
[T, val] = tv.track.chains(D);
assert(~isempty(T), 'no chain');
assert(numel(T(1).frames) == 36, sprintf('%d points', numel(T(1).frames)));
assert(all(ismember(T(1).frames, ball(:, 1))) && val(1) == max(val));

%% nothing confident: no chain
[T, ~] = tv.track.chains(noise);
assert(isempty(T));
