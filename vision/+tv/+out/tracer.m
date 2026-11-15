function img = tracer(img, cam, P, rgb, widthPx)
%TRACER  Draw a ball's path onto a camera frame (TV-OUT-04, the tracer clips).
%   P: N-by-3 court positions of the path so far (fitted, 200 Hz); drawn as
%   an anti-aliased line through the camera's lens model, fading toward the
%   start, with the ball at the end. img: H-by-W-by-3 uint8 or double.
if nargin < 4, rgb = [214 236 60]; end
if nargin < 5, widthPx = 2.2; end
cls = class(img);  img = double(img);
[px, ok] = tv.camera.project(cam, P);
px = px(ok, :);
n = size(px, 1);
if n < 2, img = cast(img, cls); return; end
H = size(img, 1);  W = size(img, 2);
for k = 2:n
    a = px(k - 1, :);  b = px(k, :);
    fade = 0.25 + 0.75 * k / n;
    lo = floor(min(a, b) - widthPx - 1);  hi = ceil(max(a, b) + widthPx + 1);
    lo = max(lo, 1);  hi = min(hi, [W H]);
    if any(hi < lo), continue; end
    [X, Y] = meshgrid(lo(1):hi(1), lo(2):hi(2));
    ab = b - a;  L2 = max(ab * ab', eps);
    t = max(0, min(1, ((X - a(1)) * ab(1) + (Y - a(2)) * ab(2)) / L2));
    dd = hypot(X - (a(1) + t * ab(1)), Y - (a(2) + t * ab(2)));
    al = fade * min(1, max(0, widthPx / 2 + 0.5 - dd));
    for ch = 1:3
        patch = img(lo(2):hi(2), lo(1):hi(1), ch);
        img(lo(2):hi(2), lo(1):hi(1), ch) = max(patch, (1 - al) .* patch + al * rgb(ch));
    end
end
% the ball now: a white ring around the last point
e = px(end, :);
[X, Y] = meshgrid(max(1, floor(e(1) - 8)):min(W, ceil(e(1) + 8)), max(1, floor(e(2) - 8)):min(H, ceil(e(2) + 8)));
ring = min(1, max(0, 1.2 - abs(hypot(X - e(1), Y - e(2)) - 5)));
for ch = 1:3
    patch = img(Y(:, 1), X(1, :), ch);
    img(Y(:, 1), X(1, :), ch) = (1 - ring) .* patch + ring * 255;
end
img = cast(img, cls);
end
