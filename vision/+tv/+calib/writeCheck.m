function J = writeCheck(outDir, C, doubt, cfg)
%WRITECHECK  The calibration question for the app: each doubtful camera's picture and fit (TV-CAL-21).
%   J = tv.calib.writeCheck(outDir, C, doubt, cfg)
%   For every camera tv.calib.doubt marks, writes into outDir/calibration:
%     cam<k>.jpg        the empty court as that camera sees it (no wider than
%                       cfg.checkPictureWidth; a wider picture is averaged down by a whole factor)
%     calibration.json  per camera: the picture's file and size, its scale against the full
%                       picture, the share of the fitted lines with paint under them, why it is
%                       asked, and the fitted court's lines as drawn through the lens, so the app
%                       can lay them over the picture
%   The file is also the mark that the session is waiting for an answer (tv.ingest.scanOnce);
%   with no doubt left it is removed.
%   Pixels in the file: x across and y down from the picture's top-left corner, so a MATLAB
%   pixel centre (u, v) of the full picture is at ((u - 0.5) * scale, (v - 0.5) * scale).
d = fullfile(outDir, 'calibration');
f = fullfile(d, 'calibration.json');
J = [];
if ~any([doubt.is])
    if exist(f, 'file'), delete(f); end
    return
end
if ~exist(d, 'dir'), mkdir(d); end
checks = {};
for k = find([doubt.is])
    bg = C.bg{k};
    n = max(1, ceil(size(bg, 2) / cfg.checkPictureWidth));
    pic = uint8(round(shrink(double(bg), n)));          % the background is 0 to 255 in doubles
    name = sprintf('cam%d.jpg', k);
    imwrite(pic, fullfile(d, name), 'Quality', 90);
    s = 1 / n;
    checks{end+1} = struct('cam', k, 'picturePath', ['calibration/' name], 'width', size(pic, 2), 'height', size(pic, 1), ...
        'scale', s, 'support', round(C.report(k).support * 1000) / 1000, 'reason', doubt(k).reason, 'text', doubt(k).text, ...
        'lines', {fittedLines(C.cams(k), s)}); %#ok<AGROW>
end
J = struct('checks', {checks});
tv.util.writeJson(f, J);
end

function pic = shrink(bg, n)
% the mean of each n-by-n block (no toolbox needed)
pic = bg;
if n == 1, return; end
h = floor(size(bg, 1) / n) * n;  w = floor(size(bg, 2) / n) * n;
x = bg(1:h, 1:w, :);
x = reshape(x, n, h / n, n, w / n, size(bg, 3));
pic = reshape(mean(mean(x, 1), 3), h / n, w / n, size(bg, 3));
end

function L = fittedLines(cam, s)
% every court line and the net tape through the fitted camera: runs of points inside the
% picture, each run a list of [x y] in the sent picture's pixels
[M, id] = tv.calib.modelPoints(0.25);
[px, ok] = tv.camera.project(cam, M);
L = {};
for k = unique(id)'
    i = find(id == k);
    in = ok(i)';
    edges = diff([false in false]);
    a = find(edges == 1);  b = find(edges == -1) - 1;
    for r = 1:numel(a)
        if b(r) - a(r) < 1, continue; end
        j = i(a(r):b(r));
        L{end+1} = round((px(j, :) - 0.5) * s * 10) / 10; %#ok<AGROW>
    end
end
end
