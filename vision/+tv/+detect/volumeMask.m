function mask = volumeMask(cam, margin, maxHeight)
%VOLUMEMASK  Image pixels whose sight line passes through the play volume (TV-DET-02).
%   The court plus margin metres all round, from the ground to maxHeight
%   (spec: 4 m margin, up to 8 m). Everything else (sky, other courts,
%   people walking past) is ignored by the ball detector.
if nargin < 2, margin = 4; end
if nargin < 3, maxHeight = 8; end
c = tv.court.constants();
xe = c.halfLength + margin;  ye = c.halfDoubles + margin;
[gx, gy, gz] = ndgrid(linspace(-xe, xe, 60), linspace(-ye, ye, 25), linspace(0, maxHeight, 17));
[px, ok] = tv.camera.project(cam, [gx(:), gy(:), gz(:)]);
mask = false(cam.height, cam.width);
idx = sub2ind(size(mask), round(min(max(px(ok,2), 1), cam.height)), round(min(max(px(ok,1), 1), cam.width)));
mask(idx) = true;
mask = imdilate(mask, ones(25));
mask = imfill(imclose(mask, ones(41)), 'holes');
end
