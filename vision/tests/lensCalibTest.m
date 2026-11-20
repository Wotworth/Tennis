% A lens calibrated from a checkerboard (TV-CAL-01, Chris's home test a, 21 Nov): the calibration file
% (vision/ml/lens_from_checkerboard.py) is read by tv.lens.fromCalibration and projects exactly as
% OpenCV does. Fixtures: tests/fixtures/lens/<name>_lens.json (a known lens) and <name>_points.csv
% (camera-frame points and the pixels OpenCV gives for them, 0-based), made with OpenCV 5.1.
here = fileparts(mfilename('fullpath'));
if isempty(here), here = fullfile(pwd, 'tests'); end
fx = fullfile(here, 'fixtures', 'lens');

%% Linear-like (standard model) and Wide-like (fisheye model) project as OpenCV does
for name = {'linear', 'wide'}
    lens = tv.lens.fromCalibration(fullfile(fx, [name{1} '_lens.json']));
    D = dlmread(fullfile(fx, [name{1} '_points.csv']), ',', 1, 0);
    [u, v, ok] = tv.lens.toPixels(lens, D(:, 1), D(:, 2), D(:, 3));
    u0 = u + (lens.widthPx - 1) / 2;  v0 = v + (lens.heightPx - 1) / 2;   % to OpenCV's 0-based pixels
    e = hypot(u0 - D(:, 4), v0 - D(:, 5));
    fprintf('%s (%s): largest difference from OpenCV %.2g px\n', name{1}, lens.type, max(e));
    assert(all(ok) && max(e) < 0.01)                % the points are stored to 6 decimals: about 0.001 px
end

%% Pixels back to sight lines: the round trip closes
for name = {'linear', 'wide'}
    lens = tv.lens.fromCalibration(fullfile(fx, [name{1} '_lens.json']));
    D = dlmread(fullfile(fx, [name{1} '_points.csv']), ',', 1, 0);
    [u, v] = tv.lens.toPixels(lens, D(:, 1), D(:, 2), D(:, 3));
    d = tv.lens.unproject(lens, u, v);
    t = D(:, 1:3) ./ sqrt(sum(D(:, 1:3).^2, 2));
    assert(max(acosd(min(1, sum(d .* t, 2)))) < 1e-4)
end
