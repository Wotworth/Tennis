function L = imageLines(mask, opts)
%IMAGELINES  Straight lines in a line-pixel mask (TV-CAL-10: "detect the white court lines").
%   mask: thin line pixels (tv.calib.linePixels). Pieces between junctions that are long and
%   straight become line segments; pieces on one straight line are merged (a court line
%   broken by a player's shadow or the net post). opts.toPlane (optional) maps pixel
%   coordinates [x y] (1-based) to the plane the fit works in (e.g. undistorted, for a
%   calibrated wide lens); default: pixel coordinates.
%   L: struct array with fields p (a point), d (unit direction), n (unit normal), c (n*q = c
%   for points q on the line), len (length in the working plane), ends (2-by-2), pix (pixels).
%   RETUNE(real footage): minLen, maxRms, mergeDeg, mergePx.
if nargin < 2, opts = struct(); end
d0 = struct('minLen', 60, 'maxRms', 1.5, 'mergeDeg', 1.5, 'mergePx', 4, 'toPlane', []);
fn = fieldnames(d0);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d0.(fn{k}); end, end
nb = conv2(double(mask), [1 1 1; 1 0 1; 1 1 1], 'same');
pieces = mask & ~(nb > 2);
[lab, n] = bwlabel(pieces, 8);
L = struct('p', {}, 'd', {}, 'n', {}, 'c', {}, 'len', {}, 'ends', {}, 'pix', {}, 'rms', {});
lin = find(lab);
groups = accumarray(lab(lin), lin, [max(n, 1) 1], @(x) {x});
for i = 1:n
    [r, c] = ind2sub(size(mask), groups{i});
    if numel(r) < opts.minLen / 2, continue; end
    q = [c, r];
    if ~isempty(opts.toPlane), q = opts.toPlane(q); end
    s = fitLine(q);
    if s.len < opts.minLen || s.rms > opts.maxRms, continue; end
    L(end+1) = s; %#ok<AGROW>
end
% merge pieces lying on one line
merged = true;
while merged
    merged = false;
    for a = 1:numel(L)
        for b = a + 1:numel(L)
            ang = acosd(min(1, abs(L(a).d * L(b).d')));
            if ang > opts.mergeDeg, continue; end
            if abs(L(a).n * L(b).p' - L(a).c) > opts.mergePx || abs(L(b).n * L(a).p' - L(b).c) > opts.mergePx, continue; end
            s = fitLine([L(a).pix; L(b).pix]);
            if s.rms > opts.maxRms, continue; end
            L(a) = s;  L(b) = [];  merged = true;
            break
        end
        if merged, break; end
    end
end
[~, o] = sort([L.len], 'descend');
L = L(o);
end

function s = fitLine(q)
m = mean(q, 1);
[~, ~, V] = svd(q - m, 'econ');
d = V(:, 1)';  nn = [-d(2) d(1)];
t = (q - m) * d';
rms = sqrt(mean(((q - m) * nn').^2));
s = struct('p', m, 'd', d, 'n', nn, 'c', nn * m', 'len', max(t) - min(t), ...
    'ends', [m + min(t) * d; m + max(t) * d], 'pix', q, 'rms', rms);
end
