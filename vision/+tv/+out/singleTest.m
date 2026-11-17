function T = singleTest(R, outDir, opts)
%SINGLETEST  A one-camera run as a "footage test" for the app (Chris, 17 Nov).
%   R: tv.pipeline.runSingle's result. Writes outDir/test.json and images:
%     court.jpg   the empty court (players removed by the median), with the overlay boxes
%                 blanked; the app draws the fitted court lines over it from test.json
%     f_NN.jpg    sample frames at opts.frameWidth px, lined up with the empty court: the
%                 ball's detections ringed, the recent track drawn, people pixelated
%                 (opts.pixelate; found against the clip's own empty court), overlays blanked
%   opts: id, title, date, source, frames (struct array: clip, frame, verdict, caption: the
%   sample frames, chosen by the caller), check (struct: the hand check's counts, or []),
%   scorecard (struct: medianPx, perPointPx, or []), notes (cellstr), frameWidth (960),
%   pixelate (true), drawTrackS (0.5).
%   Numbers only besides the images; no names. TV-APP-related; one-camera test only.
if nargin < 3, opts = struct(); end
d = struct('id', 'test', 'title', 'footage test', 'date', '', 'source', '', 'frames', struct([]), ...
           'check', [], 'scorecard', [], 'notes', {{}}, 'frameWidth', 960, 'pixelate', true, 'drawTrackS', 0.5);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
rec = R.rec;  cam = R.cam;
c = tv.court.constants();
sc = opts.frameWidth / rec.width;
% --- court picture and the fitted lines, in its pixels
imwrite(uint8(imresize(R.bg, sc)), fullfile(outDir, 'court.jpg'), 'Quality', 85);
L = tv.court.lines();
lines = {};
for i = 1:size(L, 1)
    t = linspace(0, 1, 40)';
    P = [L(i, 1:2) + t .* (L(i, 3:4) - L(i, 1:2)), zeros(40, 1)];
    [px, ok] = tv.camera.project(cam, P);
    if nnz(ok) >= 2, lines{end+1} = rnd(px(ok, :) * sc, 1); end %#ok<AGROW>
end
% the net tape, for reference only (never used to fit: Chris, 16 Nov)
y = linspace(-c.postY, c.postY, 40)';
[px, ok] = tv.camera.project(cam, [zeros(40, 1), y, tv.court.netHeight(y)]);
net = rnd(px(ok, :) * sc, 1);
% --- per clip
nC = size(R.clips, 1);
clips = struct('index', {}, 'startS', {}, 'lengthS', {}, 'frames', {}, 'framesWithBall', {}, 'tracks', {}, 'bounces', {});
totF = 0;  totB = 0;
for r = 1:nC
    f = R.clips(r, 1):R.clips(r, 2);
    tr = R.tracks{r};
    withBall = [];
    for q = tr(:)', withBall = [withBall; double(q.frames(:))]; end %#ok<AGROW>
    withBall = unique(withBall);
    nb = nnz([R.bounces.clip] == r);
    clips(end+1) = struct('index', r, 'startS', rnd(rec.pts(f(1) + 1), 2), 'lengthS', rnd(numel(f) / rec.fps, 1), ...
        'frames', numel(f), 'framesWithBall', numel(withBall), 'tracks', numel(tr), 'bounces', nb); %#ok<AGROW>
    totF = totF + numel(f);  totB = totB + numel(withBall);
end
% --- bounces (top-down)
b = R.bounces;
bounces = struct('clip', {b.clip}, 't', num2cell(rnd([b.t], 2)), 'x', num2cell(rnd([b.x], 2)), ...
    'y', num2cell(rnd([b.y], 2)), 'call', {b.call}, 'marginM', num2cell(rnd([b.marginM], 2)));
% --- players: how often two people were placed on the court
n2 = 0;  n1 = 0;
for s = R.players(:)'
    in = 0;
    for p = s.dets(:)', if abs(p.foot(1)) < c.halfLength + 6 && abs(p.foot(2)) < c.halfDoubles + 3, in = in + 1; end, end
    n2 = n2 + (in >= 2);  n1 = n1 + (in >= 1);
end
% --- sample frames
frames = struct('file', {}, 'clip', {}, 't', {}, 'verdict', {}, 'caption', {});
for i = 1:numel(opts.frames)
    q = opts.frames(i);
    % lined up with the empty court (the tracks are in its pixels: the camera moved, TV-CAL-14);
    % people found against the clip's own empty court (the light changes over a long video)
    img = double(tv.calib.steady(blank(tv.media.readFrames(rec, q.frame, 1), R.overlayBoxes), R.bg));
    if opts.pixelate, img = pixelatePeople(img, clipBackground(R, rec, q.clip), R.overlayBoxes); end
    img = drawBall(img, R, q, rec, opts.drawTrackS);
    name = sprintf('f_%02d.jpg', i);
    imwrite(uint8(imresize(img, sc)), fullfile(outDir, name), 'Quality', 82);
    frames(end+1) = struct('file', name, 'clip', q.clip, 't', rnd(rec.pts(q.frame + 1), 2), ...
        'verdict', q.verdict, 'caption', q.caption); %#ok<AGROW>
end
T = struct('id', opts.id, 'title', opts.title, 'date', opts.date, 'source', opts.source, ...
    'video', struct('lengthS', rnd(rec.pts(end), 1), 'fps', rnd(rec.fps, 2), 'width', rec.width, 'height', rec.height), ...
    'court', struct('image', 'court.jpg', 'imageWidth', opts.frameWidth, 'imageHeight', round(rec.height * sc), ...
        'lines', {lines}, 'net', net, 'hfovDeg', rnd(2 * atand(1 / cam.lens.F), 1), ...
        'camera', rnd(cam.pos, 2), 'lineRmsPx', rnd(R.calib.rmsPx, 2), 'paintShare', rnd(R.calib.support, 2), ...
        'cornersOutOfView', {R.corners.missing(:)'}, 'scorecard', opts.scorecard), ...
    'clips', clips, ...
    'ball', struct('framesInClips', totF, 'framesWithBall', totB, ...
        'candidates', sum(cellfun(@(x) size(x, 1), R.candidates)), 'tracks', sum(cellfun(@numel, R.tracks)), ...
        'check', opts.check), ...
    'bounces', bounces, ...
    'players', struct('samples', numel(R.players), 'withTwoOnCourt', n2, 'withOneOrMore', n1), ...
    'frames', frames, 'notes', {opts.notes});
tv.util.writeJson(fullfile(outDir, 'test.json'), T);
end

function img = blank(img, boxes)
for b = 1:size(boxes, 1)
    img(max(1, boxes(b, 2)):min(end, boxes(b, 4)), max(1, boxes(b, 1)):min(end, boxes(b, 3)), :) = 128;
end
end

function bg = clipBackground(R, rec, r)
% the median of 15 frames across clip r, each blanked and lined up with the empty court
f = unique(round(linspace(R.clips(r, 1), R.clips(r, 2), 15)));
B = zeros(rec.height, rec.width, 3, numel(f), 'uint8');
for i = 1:numel(f), B(:, :, :, i) = tv.calib.steady(blank(tv.media.readFrames(rec, f(i), 1), R.overlayBoxes), R.bg); end
bg = double(median(B, 4));
end

function img = pixelatePeople(img, bg, boxes)
% people: large regions that differ from the empty court; each box, padded, becomes coarse
% 24-px blocks (faces and bodies unrecognisable; the ball, drawn after, stays visible)
fg = sum(abs(img - bg), 3) > 60;
fg = imclose(imopen(fg, true(3)), true(15));
fg = blank(double(fg), boxes) == 1;
L = bwlabel(fg, 8);
st = regionprops(L, 'BoundingBox', 'Area');
blk = 24;
for i = 1:numel(st)
    if st(i).Area < 1500, continue; end
    bb = st(i).BoundingBox;  pad = 0.25 * max(bb(3), bb(4));
    x0 = max(1, floor(bb(1) - pad));  y0 = max(1, floor(bb(2) - pad));
    x1 = min(size(img, 2), ceil(bb(1) + bb(3) + pad));  y1 = min(size(img, 1), ceil(bb(2) + bb(4) + pad));
    for yy = y0:blk:y1
        for xx = x0:blk:x1
            ys = yy:min(y1, yy + blk - 1);  xs = xx:min(x1, xx + blk - 1);
            img(ys, xs, :) = repmat(mean(mean(img(ys, xs, :), 1), 2), numel(ys), numel(xs), 1);
        end
    end
end
end

function img = drawBall(img, R, q, rec, trackS)
% the clip's track points over the last trackS seconds (green dots), and a ring round the
% detection in this frame (magenta), if any
tr = R.tracks{q.clip};
nBack = round(trackS * rec.fps);
for t = tr(:)'
    f = double(t.frames(:));
    m = f <= q.frame & f >= q.frame - nBack;
    for j = find(m)'
        img = dot(img, t.uv(j, :), 3, [80 255 80]);
    end
    k = find(f == q.frame, 1);
    if ~isempty(k), img = ring(img, t.uv(k, :), 16, [255 0 255]); end
end
end

function img = dot(img, p, r, rgb)
[X, Y] = meshgrid(-r:r);  m = X.^2 + Y.^2 <= r^2;
for i = find(m)'
    x = round(p(1) + X(i));  y = round(p(2) + Y(i));
    if x >= 1 && y >= 1 && x <= size(img, 2) && y <= size(img, 1), img(y, x, :) = reshape(rgb, 1, 1, 3); end
end
end

function img = ring(img, p, r, rgb)
for a = linspace(0, 2 * pi, 200)
    for w = -1.5:0.5:1.5
        x = round(p(1) + (r + w) * cos(a));  y = round(p(2) + (r + w) * sin(a));
        if x >= 1 && y >= 1 && x <= size(img, 2) && y <= size(img, 1), img(y, x, :) = reshape(rgb, 1, 1, 3); end
    end
end
end

function y = rnd(x, n)
% round to n decimals (Octave's round takes no digits argument)
y = round(double(x) * 10^n) / 10^n;
end
