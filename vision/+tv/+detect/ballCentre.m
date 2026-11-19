function xy = ballCentre(cur, bg, xy0, blob, hi)
%BALLCENTRE  Where a moving spot's centre really is: the middle of what differs from the empty court.
%   xy = tv.detect.ballCentre(cur, bg, xy0, blob, hi)
%   cur: the frame, lined up with the empty court bg (same size; any numeric class). xy0: the
%   spot's position [x y] from tv.detect.motionProposals. blob: that spot's own
%   [area length width] (px). hi: the largest a ball can look there (px).
%   Why: the moving-spot finder sees only what changed between frames, which is cut short
%   wherever the ball overlaps its own place a moment earlier or later, so its middle sits off
%   the ball's by a fraction of the ball. No colour is used.
% A patch the spot's length and a ball each way; the patch's own middle level and spread set the
% threshold, so a brighter or dimmer frame (flicker, a cloud) does not matter; the piece under
% the spot, or the nearest within the spot's own width of it, is weighed by how much it differs.
% The spot's own position stands when nothing differs there, when the piece is much larger than
% the spot (it has merged with a player, a racquet or the net: first real clip, 19 Nov), when it
% runs off the patch, or when its middle is further from the spot than half the spot's length:
% a ball's whole streak cannot be centred further than that from the part of it that moved.
xy = xy0;
[h, w, ~] = size(cur);
area = blob(1);  len = blob(2);  wid = blob(3);
r = ceil(0.5 * len + min(hi, len + wid) + 2);
cx = round(xy0(1));  cy = round(xy0(2));
xs = max(1, cx - r):min(w, cx + r);  ys = max(1, cy - r):min(h, cy + r);
if numel(xs) < 5 || numel(ys) < 5, return; end
D = sum(abs(double(cur(ys, xs, :)) - double(bg(ys, xs, :))), 3);   % only the patch is converted
b = median(D(:));
fg = D - (b + 4 * (1.4826 * median(abs(D(:) - b)) + 1));
B = fg > 0;
if ~any(B(:)), return; end
L = bwlabel(B, 8);
[yy, xx] = find(B);
[dn, j] = min(hypot(xx + xs(1) - 1 - xy0(1), yy + ys(1) - 1 - xy0(2)));
if dn > 0.5 * wid + 1.5, return; end
sel = L == L(yy(j), xx(j));
% no more than six times the moving part, or a disc as wide as the moving part is long (a slow
% ball shows only a thin crescent, about as long as the ball is wide), whichever is larger
if nnz(sel) > max(6 * area + 12, 1.2 * (len + 1) ^ 2) || nnz(sel) > (len + 2 * hi + 2) * (2 * hi + 2), return; end
if any(sel(1, :)) || any(sel(end, :)) || any(sel(:, 1)) || any(sel(:, end)), return; end
[yy, xx] = find(sel);
wt = fg(sel);
new = [sum(xx .* wt) / sum(wt) + xs(1) - 1, sum(yy .* wt) / sum(wt) + ys(1) - 1];
if norm(new - xy0) > 0.5 * max(len, wid) + 1.5, return; end
xy = new;
%   RETUNE(real footage): the threshold (4 robust deviations over the patch's own level) and the
%   three limits above (6 times the spot's area or a disc of its length, half its length plus
%   1.5 px, its width).
end
