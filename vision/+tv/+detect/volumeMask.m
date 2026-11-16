function mask = volumeMask(cam, margin, maxHeight)
%VOLUMEMASK  Image pixels whose sight line passes through the play volume (TV-DET-02).
%   volumeMask(cam, box): the court of interest (tv.court.interest, TV-ADJ-01; 16 Nov).
%   volumeMask(cam, margin, maxHeight): the court plus margin metres all round,
%   from the ground to maxHeight (the spec before 16 Nov: 4 m, 8 m).
%   Everything else (sky, people walking past) is ignored by the ball detector;
%   a neighbouring court can still show through it, and is removed in 3D (tv.recon.gateTracks).
%   RETUNE(real footage): the margin, and the mask's dilation (25 px) and
%   closing (41 px) at 4K.
if nargin >= 2 && isstruct(margin)
    box = margin;
else
    if nargin < 2, margin = 4; end
    if nargin < 3, maxHeight = 8; end
    c = tv.court.constants();
    box = struct('x', (c.halfLength + margin) * [-1 1], 'y', (c.halfDoubles + margin) * [-1 1], 'z', [0 maxHeight]);
end
[gx, gy, gz] = ndgrid(linspace(box.x(1), box.x(2), 60), linspace(box.y(1), box.y(2), 25), ...
    linspace(max(0, box.z(1)), box.z(2), 17 + 8 * (box.z(2) > 8)));
[px, ok] = tv.camera.project(cam, [gx(:), gy(:), gz(:)]);
mask = false(cam.height, cam.width);
idx = sub2ind(size(mask), round(min(max(px(ok,2), 1), cam.height)), round(min(max(px(ok,1), 1), cam.width)));
mask(idx) = true;
mask = imdilate(mask, ones(25));
mask = imfill(imclose(mask, ones(41)), 'holes');
end
