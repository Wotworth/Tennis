function img = renderBackground(cam, sc)
%RENDERBACKGROUND  The empty court as one camera sees it (H-by-W-by-3, 0-255 double).
%   Ray-traced through the lens model with 2x2 supersampling: blue court,
%   green surround, white lines, the net with its tape and posts, dark green
%   fences and sky. Mild fixed texture so the court is not perfectly flat.
%   RETUNE(real footage): real courts have shadows, stains, worn lines,
%   neighbouring courts and people; the line detector's thresholds are set
%   on this clean picture.
c = tv.court.constants();
W = cam.width;  H = cam.height;  ss = 2;
[u, v] = meshgrid(((1:W*ss) - 0.5) / ss + 0.5, ((1:H*ss) - 0.5) / ss + 0.5);
D = tv.camera.rays(cam, [u(:), v(:)]);
p = cam.pos;  n = size(D, 1);

col = repmat([185 200 215], n, 1);                        % sky
dist = inf(n, 1);
% fences: back fences 6.4 m behind each baseline, far side fence 4 m out; 3.5 m high
planes = {[1 0 0],  c.halfLength + 6.4;  [-1 0 0], c.halfLength + 6.4;  [0 1 0], c.halfDoubles + 4};
nbr = [];  if isfield(sc, 'neighbourCourts'), nbr = sc.neighbourCourts; end
if isfield(sc, 'sideFence') && ~sc.sideFence
    planes = planes(1:2, :);                              % public courts in a row: no fence between
    planes(end+1, :) = {[0 1 0], max(nbr) + c.halfDoubles + 4};
end
for k = 1:size(planes, 1)
    nrm = planes{k, 1};  off = planes{k, 2};
    s = (off - p * nrm') ./ (D * nrm');
    q = p + s .* D;
    hit = s > 0 & q(:,3) >= 0 & q(:,3) <= 3.5 & s < dist;
    col(hit, :) = repmat([38 70 48], nnz(hit), 1);
    dist(hit) = s(hit);
end
% ground
s = -p(3) ./ D(:,3);
q = p + s .* D;
g = s > 0 & s < dist;
x = q(g, 1);  y = q(g, 2);
gc = repmat([62 120 78], numel(x), 1);                    % green surround
inCourt = abs(x) <= c.halfLength + 0.05 & abs(y) <= c.halfDoubles + 0.05;
for o = nbr, inCourt = inCourt | (abs(x) <= c.halfLength + 0.05 & abs(y - o) <= c.halfDoubles + 0.05); end
gc(inCourt, :) = repmat([52 92 150], nnz(inCourt), 1);    % blue court(s)
tex = 1 + 0.03 * sin(0.9 * x + 0.3) .* cos(1.3 * y) + 0.02 * sin(4.1 * x + 2.7 * y);
gc = gc .* tex;
isL = tv.court.isLine(x, y);
for o = nbr, isL = isL | tv.court.isLine(x, y - o); end   % the neighbours' lines too
gc(isL, :) = repmat([236 238 236], nnz(isL), 1);
col(g, :) = gc;  dist(g) = s(g);
% net (semi-transparent mesh, white tape, dark posts)
s = -p(1) ./ D(:,1);
q = p + s .* D;
inNet = s > 0 & s < dist & abs(q(:,2)) <= c.postY & q(:,3) >= 0;
hN = tv.court.netHeight(q(:,2));
mesh = inNet & q(:,3) <= hN - 0.06;
tape = inNet & q(:,3) > hN - 0.06 & q(:,3) <= hN;
col(mesh, :) = 0.45 * col(mesh, :) + 0.55 * 35;
col(tape, :) = repmat([240 240 240], nnz(tape), 1);
post = s > 0 & s < dist & abs(abs(q(:,2)) - c.postY) < 0.04 & q(:,3) >= 0 & q(:,3) <= c.netHeightPost;
col(post, :) = repmat([50 55 50], nnz(post), 1);
for o = nbr                                               % the neighbours' nets
    yy = q(:,2) - o;
    inN = s > 0 & s < dist & abs(yy) <= c.postY & q(:,3) >= 0;
    hN = tv.court.netHeight(yy);
    col(inN & q(:,3) <= hN - 0.06, :) = 0.45 * col(inN & q(:,3) <= hN - 0.06, :) + 0.55 * 35;
    tp = inN & q(:,3) > hN - 0.06 & q(:,3) <= hN;
    col(tp, :) = repmat([240 240 240], nnz(tp), 1);
end

img = reshape(col, H*ss, W*ss, 3);
img = (img(1:2:end, 1:2:end, :) + img(2:2:end, 1:2:end, :) + img(1:2:end, 2:2:end, :) + img(2:2:end, 2:2:end, :)) / 4;
end
