function D = detect(img, bg, cam, opts)
%DETECT  People in one frame, placed on the court (TV-PLY-01).
%   Synthetic and test footage: people are the large upright blobs that
%   differ from the empty court. Each gets
%     foot  [x y]: where the bottom centre of its box meets the ground
%     height: from the top of the box, straight above the foot point (m)
%     cap:    share of magenta pixels in the top of the box (TV-PLY-03)
%     shirt:  median colour across the chest (for re-identification)
%   On the PC the same outputs can come from the pretrained person detector
%   (opts.method = 'acf', Computer Vision Toolbox), which copes with real
%   clothes and shadows.
%   People whose feet are hidden come out the wrong height and are skipped
%   (opts.heightRange); the other camera usually sees them.
%   RETUNE(real footage): use 'acf' (or a better detector); the foreground
%   threshold, minimum size, height range, magenta colour range, chest band.
if nargin < 4, opts = struct(); end
d = struct('method', 'foreground', 'thr', 45, 'minArea', 40, 'minAspect', 1.2, 'heightRange', [1.3 2.3], ...
           'capHue', [285 345], 'capSat', 0.40, 'capVal', 0.30);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
img = double(img);
D = struct('box', {}, 'foot', {}, 'height', {}, 'cap', {}, 'shirt', {});
switch opts.method
    case 'acf'
        det = peopleDetectorACF();
        boxes = detect(det, uint8(img));
        fg = true(size(img, 1), size(img, 2));
    otherwise
        fg = sum(abs(img - bg), 3) > opts.thr;
        fg = imopen(fg, ones(2));  fg = imclose(fg, ones(5));
        cc = bwconncomp(fg, 8);
        st = regionprops(cc, 'BoundingBox', 'Area');
        boxes = zeros(0, 4);
        for b = 1:numel(st)
            bb = st(b).BoundingBox;
            if st(b).Area >= opts.minArea && bb(4) / bb(3) >= opts.minAspect
                boxes(end+1, :) = bb; %#ok<AGROW>
            end
        end
end
mx = max(img, [], 3);  mn = min(img, [], 3);
sat = (mx - mn) ./ max(mx, 1);  val = mx / 255;
hue = hueDeg(img, mx, mn);
magenta = hue >= opts.capHue(1) & hue <= opts.capHue(2) & sat >= opts.capSat & val >= opts.capVal;
for b = 1:size(boxes, 1)
    bb = boxes(b, :);
    x0 = max(1, floor(bb(1)));  x1 = min(size(img, 2), ceil(bb(1) + bb(3)));
    y0 = max(1, floor(bb(2)));  y1 = min(size(img, 1), ceil(bb(2) + bb(4)));
    footPx = [(x0 + x1) / 2, y1];  topPx = [(x0 + x1) / 2, y0];
    ray = tv.camera.rays(cam, footPx);
    if ray(3) >= 0, continue; end
    s = -cam.pos(3) / ray(3);
    foot = cam.pos + s * ray;
    % height: the top ray's closest point to the vertical line above the foot
    rt = tv.camera.rays(cam, topPx);
    h = closestHeight(cam.pos, rt, foot(1:2));
    % a box whose feet are hidden (behind the net, cut by the frame edge)
    % lands its foot point far away and comes out the wrong height: skip it
    if h < opts.heightRange(1) || h > opts.heightRange(2), continue; end
    hb = max(1, round((y1 - y0 + 1) * 0.12));
    capShare = mean(mean(magenta(y0:y0 + hb - 1, x0:x1)));
    rows = y0 + round((y1 - y0) * [0.25 0.42]);
    band = img(rows(1):rows(2), x0:x1, :);  m = fg(rows(1):rows(2), x0:x1);
    shirt = zeros(1, 3);
    for ch = 1:3, v = band(:, :, ch); if any(m(:)), shirt(ch) = median(v(m)); end, end
    D(end+1) = struct('box', [x0 y0 x1 - x0 y1 - y0], 'foot', foot(1:2), 'height', h, 'cap', capShare, 'shirt', shirt); %#ok<AGROW>
end
end

function h = closestHeight(o, d, xy)
% point on the ray o + s d closest to the vertical line through (xy, z)
w = o(1:2) - xy;  dh = d(1:2);
s = -(w * dh') / max(dh * dh', eps);
h = o(3) + s * d(3);
end

function h = hueDeg(img, mx, mn)
r = img(:, :, 1);  g = img(:, :, 2);  b = img(:, :, 3);
dd = max(mx - mn, 1e-6);
h = zeros(size(r));
k = mx == r;  h(k) = mod((g(k) - b(k)) ./ dd(k), 6);
k = mx == g & ~(mx == r);  h(k) = (b(k) - r(k)) ./ dd(k) + 2;
k = mx == b & ~(mx == r) & ~(mx == g);  h(k) = (r(k) - g(k)) ./ dd(k) + 4;
h = 60 * h;
end
