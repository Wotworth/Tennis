% tv.track.inPlay: one ball in play at a time, the most valuable chain wins where chains overlap
mk = @(f, x) struct('frames', f(:), 'uv', [x(:), 0 * x(:) + 100], 'area', zeros(numel(f), 1), 'id', 0, 'score', ones(numel(f), 1));
T = [mk(1:20, 1:20), mk(15:40, 500 + (15:40)), mk(30:33, 900 + (30:33))];
value = [10; 25; 8];

%% the more valuable chain keeps the frames both cover
P = tv.track.inPlay(T, value);
assert(numel(P) == 2, sprintf('%d chains', numel(P)));
assert(isequal(P(1).frames(:)', 1:14) && isequal(P(2).frames(:)', 15:40));

%% a chain left too short is dropped (the third is fully covered)
P = tv.track.inPlay(T, value);
assert(~any(arrayfun(@(t) any(t.uv(:, 1) > 900), P)));
