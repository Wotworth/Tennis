% tv.detect.ballCentre (TV-DET-04, 19 Nov): the learned detector's spots are placed on the middle
% of what differs from the empty court, because the moving-spot finder's own middle is cut short
% where the ball overlaps its place a moment earlier.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; pkg load statistics; end

%% A ball that overlaps its earlier place: the moving part's middle is off, the new centre is on
tv.util.seed(2);
[X, Y] = meshgrid(1:60, 1:50);
bg = 90 + 3 * randn(50, 60, 3);
errOld = [];  errNew = [];
for trial = 1:30
    c = [25 + 10 * rand(), 20 + 10 * rand()];  d = 5 + 3 * rand();
    step = (0.4 + 0.5 * rand()) * d * [cos(trial), sin(trial)];              % less than a diameter between frames
    in = @(p) hypot(X - p(1), Y - p(2)) <= d / 2;
    cur = uint8(bg + 110 * min(max(d / 2 + 0.5 - hypot(X - c(1), Y - c(2)), 0), 1) + 2 * randn(50, 60, 3));
    % what the moving-spot finder sees: the part of the ball that is in neither neighbour's place
    % (it takes the smaller of the two differences), here the larger of the two crescents
    moved = in(c) & ~in(c - step) & ~in(c + step);
    if nnz(moved) < 2, moved = in(c) & ~in(c - step); end
    [yy, xx] = find(moved);
    xy0 = [mean(xx), mean(yy)];
    ev = sort(eig(cov([xx yy]) + 0.25 * eye(2)));
    xy = tv.detect.ballCentre(cur, bg, xy0, [numel(xx), 4 * sqrt(ev(2)), 4 * sqrt(ev(1))], 10);
    errOld(end+1) = norm(xy0 - c);  errNew(end+1) = norm(xy - c); %#ok<SAGROW>
end
fprintf('30 overlapping balls: the moving part''s middle is %.2f px off (median), the new centre %.2f px; worst %.2f and %.2f\n', ...
    median(errOld), median(errNew), max(errOld), max(errNew));
assert(median(errNew) < 0.15 && max(errNew) < 0.5)
assert(median(errNew) < 0.5 * median(errOld))

%% A brighter frame (flicker, a cloud) does not move the centre
tv.util.seed(3);
[X, Y] = meshgrid(1:60, 1:50);
bg = 90 + 3 * randn(50, 60, 3);
ball = min(max(3.5 - hypot(X - 30.3, Y - 24.6), 0), 1);
cur = 1.15 * (bg + 110 * ball) + 2 * randn(50, 60, 3);
xy = tv.detect.ballCentre(uint8(cur), bg, [31 25], [12 5 4], 10);
assert(norm(xy - [30.3 24.6]) < 0.2, sprintf('centre %.2f %.2f', xy))

%% The spot's own position stands when there is nothing to centre on, or too much
tv.util.seed(4);
[X, Y] = meshgrid(1:60, 1:50);
bg = 90 + 3 * randn(50, 60, 3);
xy = tv.detect.ballCentre(uint8(bg + 2 * randn(50, 60, 3)), bg, [30.4 25.2], [12 5 4], 10);
assert(isequal(xy, [30.4 25.2]))                                           % nothing differs from the empty court
body = double(X > 22 & X < 44 & Y > 8 & Y < 44);                           % a player's body under the spot
xy = tv.detect.ballCentre(uint8(bg + 80 * body), bg, [30.4 25.2], [12 5 4], 10);
assert(isequal(xy, [30.4 25.2]))                                           % far larger than the spot: not a ball's streak
ball = min(max(3.5 - hypot(X - 37, Y - 25), 0), 1);                        % a ball, but 6.6 px from a small spot
xy = tv.detect.ballCentre(uint8(bg + 110 * ball), bg, [30.4 25.2], [4 2 1], 10);
assert(isequal(xy, [30.4 25.2]))
