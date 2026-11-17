% tv.calib.steady: frames moved by wind are lined up with the empty court (TV-CAL-14)
rand('seed', 3);
H = 240;  W = 320;
[xx, yy] = meshgrid(1:W + 60, 1:H + 60);
big = 100 + 40 * sin(xx / 7) .* cos(yy / 11) + 30 * (mod(floor(xx / 23) + floor(yy / 17), 2));
big(100:104, :) = 230;  big(:, 150:153) = 230;                  % court lines
bigRgb = uint8(repmat(big, 1, 1, 3));
bg = bigRgb(31:30 + H, 31:30 + W, :);
moves = [0 0; 7 -4; -12 9; 3 3];                               % [du dv] of each frame
F = zeros(H, W, 3, size(moves, 1), 'uint8');
for n = 1:size(moves, 1)
    F(:, :, :, n) = bigRgb(31 - moves(n, 2):30 + H - moves(n, 2), 31 - moves(n, 1):30 + W - moves(n, 1), :);
end
F(60:63, 200:203, :, 2) = 255;                                 % a small bright thing in one frame

%% each frame's movement is found to the pixel
[G, d] = tv.calib.steady(F, bg);
assert(isequal(d, moves), mat2str(d));

%% after the shift the frames lie on the empty court (away from the uncovered edges)
[G, d] = tv.calib.steady(F, bg);
for n = 1:size(moves, 1)
    e = abs(double(G(20:end - 20, 20:end - 20, 1, n)) - double(bg(20:end - 20, 20:end - 20, 1)));
    e(40:55, 165:185) = 0;                                     % the bright thing, moved with the frame
    assert(max(e(:)) == 0, sprintf('frame %d off by %g', n, max(e(:))));
end

%% a still camera is left alone, and a shift beyond the limit is not applied
[G, d] = tv.calib.steady(repmat(bg, 1, 1, 1, 2), bg);
assert(isequal(d, zeros(2, 2)) && isequal(G(:, :, :, 1), bg));
[~, d] = tv.calib.steady(F(:, :, :, 3), bg, 10);
assert(isequal(d, [0 0]), mat2str(d));
