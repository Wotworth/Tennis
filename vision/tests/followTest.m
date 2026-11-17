% tv.track.follow: a faint ball between two strong stretches is found where the track says
% it should be, and the two tracks become one (Chris, 17 Nov)
H = 120;  W = 200;  N = 40;
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end   % (MATLAB: Image Processing Toolbox)
bg = repmat(reshape(uint8([60 90 160]), 1, 1, 3), H, W);
f = (1:N)';
truth = [20 + 4 * f, 100 - 6 * f + 0.15 * f .^ 2];            % a flight: across and up, then down
F = repmat(bg, 1, 1, 1, N);
F(30:33, 150:153, :, :) = 255 * ones(4, 4, 3, N, 'uint8');      % a pale yellow patch that never moves
F(30:33, 150:153, 3, :) = 120;
for n = 1:N
    col = [220 240 90];                                        % strong: the detector finds it
    if n >= 20 && n <= 27, col = [200 215 160]; end            % faint: too pale for the detector
    [xx, yy] = meshgrid(1:W, 1:H);
    in = hypot(xx - truth(n, 1), yy - truth(n, 2)) <= 2.2;
    for c = 1:3, ch = F(:, :, c, n); ch(in) = col(c); F(:, :, c, n) = ch; end
end
readF = @(a, n) F(:, :, :, a:a + n - 1);
mask = true(H, W);
mk = @(ff, id) struct('frames', ff, 'uv', truth(ff, :), 'area', 12 * ones(numel(ff), 1), 'id', id);

%% the faint stretch is filled and the two tracks are joined
T = [mk((1:19)', 1), mk((28:40)', 2)];
[S, added] = tv.track.follow(T, readF, bg, mask, [1 N]);
assert(numel(S) == 1, sprintf('%d tracks', numel(S)));
assert(added >= 8, sprintf('%d added', added));
got = double(S.frames);
assert(all(ismember(20:27, got)), mat2str(got'));
[~, ia] = ismember(20:27, got);
e = hypot(S.uv(ia, 1) - truth(20:27, 1), S.uv(ia, 2) - truth(20:27, 2));
assert(max(e) < 1, sprintf('off by %.2f px', max(e)));
assert(all(S.followed(ia)) && ~any(S.followed(1:19)));    % the points found here are marked

%% where there is no ball, nothing is added, and a still patch near the path is not taken
G = repmat(bg, 1, 1, 1, N);
G(30:33, 150:153, :, :) = F(30:33, 150:153, :, :);
for n = 1:10, G(:, :, :, n) = F(:, :, :, n); end                % the ball only in frames 1-10
readG = @(a, n) G(:, :, :, a:a + n - 1);
[S, added] = tv.track.follow(mk((1:10)', 1), readG, bg, mask, [1 N]);
assert(added == 0 && isequal(double(S.frames(:)), (1:10)'), sprintf('%d added', added));
