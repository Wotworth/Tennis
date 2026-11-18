% tv.detect.motionProposals: a small moving ball is proposed whatever its colour; a line that
% sways by a pixel, the camera's own shake and the frame's edge are not (TV-DET-04)
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end
rand('seed', 3);  randn('seed', 3);
H = 240;  W = 320;
bg = conv2(rand(H + 8, W + 8), ones(5) / 25, 'valid');
bg = 60 + 140 * (bg(1:H, 1:W) - min(bg(:))) / (max(bg(:)) - min(bg(:)));
[xx, yy] = meshgrid(1:W, 1:H);
S = struct('mask', true(H, W), 'dmin', 3 * ones(H, W), 'dmax', 8 * ones(H, W));
% three frames: ball x, net cord row and camera shake per frame (no local functions: Octave and
% MATLAB place them differently in scripts)
paint = @(bg, xx, yy, ballX, lineY, c) bg .* ~(abs(yy - lineY) < 1 | hypot(xx - ballX, yy - 120) <= 2.5) ...
    + 20 * (abs(yy - lineY) < 1 & hypot(xx - ballX, yy - 120) > 2.5) + c * (hypot(xx - ballX, yy - 120) <= 2.5);
make =@(ballX, lineY, colour, shake) uint8(min(max(circshift( ...
    cat(3, paint(bg, xx, yy, ballX, lineY, colour(1)), paint(bg, xx, yy, ballX, lineY, colour(2)), ...
    paint(bg, xx, yy, ballX, lineY, colour(3))), [shake 0]) + 2 * randn(H, W, 3), 0), 255));

%% a ball of any colour is proposed; the swaying cord and the shake are not
for colour = {[230 230 60], [250 250 250], [200 120 60]}
    prev = make(100, 61, colour{1}, [3 -2]);
    cur = make(110, 60, colour{1}, [0 0]);
    nxt = make(120, 59, colour{1}, [-2 3]);
    C = tv.detect.motionProposals(prev, cur, nxt, S);
    d = hypot(C(:, 1) - 110, C(:, 2) - 120);
    assert(any(d < 2), sprintf('ball (%d %d %d) not proposed', colour{1}));
    assert(nnz(d >= 2) == 0, sprintf('%d other proposals', nnz(d >= 2)));
end

%% nothing moves: nothing proposed, even at the frame's edge after a shake
prev = make(-50, 60, [230 230 60], [4 4]);
cur = make(-50, 60, [230 230 60], [0 0]);
nxt = make(-50, 60, [230 230 60], [-4 -4]);
C = tv.detect.motionProposals(prev, cur, nxt, S);
assert(isempty(C), sprintf('%d proposals on a still scene', size(C, 1)));
