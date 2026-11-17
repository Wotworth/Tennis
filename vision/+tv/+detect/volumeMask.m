function mask = volumeMask(cam, margin, maxHeight)
%VOLUMEMASK  Image pixels whose sight line passes through the play volume (TV-DET-02).
%   volumeMask(cam, box): the court of interest (tv.court.interest, TV-ADJ-01; 16 Nov).
%   volumeMask(cam, margin, maxHeight): the court plus margin metres all round,
%   from the ground to maxHeight (the spec before 16 Nov: 4 m, 8 m).
%   Everything else (sky, people walking past) is ignored by the ball detector;
%   a neighbouring court can still show through it, and is removed in 3D (tv.recon.gateTracks).
%   Each pixel's sight line is tested against the box exactly (slab test), then the mask is
%   widened by 9 px so a ball at the edge keeps its whole blob. Until 17 Nov the mask was
%   a grid of projected points, dilated and closed: near the camera the points fell too far
%   apart and left holes where the near player stands (first real footage, video 1).
%   RETUNE(real footage): the 9 px widening.
if nargin >= 2 && isstruct(margin)
    box = margin;
else
    if nargin < 2, margin = 4; end
    if nargin < 3, maxHeight = 8; end
    c = tv.court.constants();
    box = struct('x', (c.halfLength + margin) * [-1 1], 'y', (c.halfDoubles + margin) * [-1 1], 'z', [0 maxHeight]);
end
lo = [box.x(1), box.y(1), max(0, box.z(1))];
hi = [box.x(2), box.y(2), box.z(2)];
o = cam.pos(:)';
mask = false(cam.height, cam.width);
cols = 1:cam.width;
for r0 = 1:100:cam.height
    rows = r0:min(cam.height, r0 + 99);
    [uu, vv] = meshgrid(cols, rows);
    [D, ok] = tv.camera.rays(cam, [uu(:), vv(:)]);
    t1 = (lo - o) ./ D;  t2 = (hi - o) ./ D;
    t1(isnan(t1)) = -Inf;  t2(isnan(t2)) = Inf;
    tin = max(min(t1, t2), [], 2);  tout = min(max(t1, t2), [], 2);
    hit = ok(:) & tout >= max(tin, 0);
    mask(rows, :) = reshape(hit, numel(rows), cam.width);
end
mask = imdilate(mask, true(9));
end
