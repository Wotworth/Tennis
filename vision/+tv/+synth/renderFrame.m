function img = renderFrame(cam, bg, sc, truth, n, rng0)
%RENDERFRAME  Frame n (0-based) of one synthetic camera, as uint8 H-by-W-by-3.
%   The ball is drawn where it really was when each image row was exposed
%   (rolling shutter: row v is read readout*(v-1)/H after row 1), smeared
%   over the shutter time (motion blur), and drawn ballDrawScale times its
%   true size. Players are simple figures: legs, shorts, shirt, head and cap.
%   Then flicker and sensor noise.
%   RETUNE(real footage): real players, shadows, compression and the ball's
%   real look all differ from this; the detector's colour and size gates are
%   set on these pictures first.
H = cam.height;  W = cam.width;
clock = cam.recordStart + n / cam.fps;                 % camera clock, start of row 1
Tmid  = tv.synth.truthTime(cam, clock + cam.readout / 2 + cam.shutter / 2);
img = bg;

% --- players, farther one first (the neighbours' too: TV-ADJ-07) -----------------
xy = [tv.synth.playerAt(truth, 1, Tmid); tv.synth.playerAt(truth, 2, Tmid)];
looks = sc.players(1:2);
if isfield(truth, 'others')
    for o = truth.others.players(:)'
        xy(end+1, :) = tv.synth.playerAt(struct('players', {{o.way}}), 1, Tmid); %#ok<AGROW>
        looks(end+1) = sc.otherLooks(o.look); %#ok<AGROW>
    end
end
dists = sqrt(sum((xy - cam.pos(1:2)).^2, 2));
[~, order] = sort(dists, 'descend');
for p = order(:)'
    img = drawPlayer(img, cam, [xy(p, :), 0], looks(p), Tmid);
end

% --- balls ----------------------------------------------------------------------
for sb = 1:size(sc.staticBall, 1)                   % balls lying still (one or several rows; 22 Nov)
    if ~all(isfinite(sc.staticBall(sb, :))), continue; end
    p = sc.staticBall(sb, :);
    img = drawBall(img, cam, sc, @(T) repmat(p, numel(T), 1), clock);
end
if isfield(truth, 'others')
    for o = truth.others.balls(:)'
        tb = struct('T', truth.T, 'ballP', o.ballP);
        img = drawBall(img, cam, sc, @(T) tv.synth.ballAt(tb, T), clock);
    end
end
img = drawBall(img, cam, sc, @(T) tv.synth.ballAt(truth, T), clock);

% --- flicker and noise ------------------------------------------------------------
img = img * (1 + sc.flicker * sin(2 * pi * sc.flickerHz * Tmid));
tv.util.seed(rng0 + n);
img = img + sc.noiseSigma * randn(size(img));
img = uint8(max(0, min(255, round(img))));
end

function img = drawBall(img, cam, sc, where, clock)
c = tv.court.constants();
H = cam.height;
% rolling shutter: find the row the ball is on, and the time that row was exposed
v = H / 2;
for it = 1:3
    T = tv.synth.truthTime(cam, clock + cam.readout * (v - 1) / H + cam.shutter / 2);
    P = where(T);
    if any(isnan(P)), return; end
    [px, ok] = tv.camera.project(cam, P);
    if ~ok, return; end
    v = min(max(px(2), 1), H);
end
% motion blur: five instants across the shutter
Ts = T + cam.shutter * linspace(-0.5, 0.5, 5)';
Ps = where(Ts);
if any(isnan(Ps(:))), Ps = repmat(P, 5, 1); end
[pxs, oks] = tv.camera.project(cam, Ps);
if ~all(oks), return; end
% apparent radius: project a point one ball radius across the sight line
ray = P - cam.pos;  side = cross(ray, [0 0 1]);  side = side / norm(side);
pe = tv.camera.project(cam, P + side * c.ballRadius);
r = max(0.5, norm(pe - pxs(3, :)) * sc.ballDrawScale);
lo = floor(min(pxs) - r - 2);  hi = ceil(max(pxs) + r + 2);
lo = max(lo, 1);  hi = min(hi, [cam.width, cam.height]);
if any(hi < lo), return; end
[X, Y] = meshgrid(lo(1):hi(1), lo(2):hi(2));
a = zeros(size(X));
for k = 1:5
    a = a + min(1, max(0, r + 0.5 - hypot(X - pxs(k,1), Y - pxs(k,2)))) / 5;
end
shade = 1 - 0.18 * max(0, min(1, (Y - pxs(3,2)) / max(r, 1)));    % darker underneath
for ch = 1:3
    patch = img(lo(2):hi(2), lo(1):hi(1), ch);
    img(lo(2):hi(2), lo(1):hi(1), ch) = (1 - a) .* patch + a .* (sc.ballRGB(ch) * shade);
end
end

function img = drawPlayer(img, cam, foot, pl, T)
% Parts as [from to] fractions of height, half-width (m) and colour.
h = pl.height;
skin = [196 150 120];
capColour = pl.cap;
if T > pl.capUntil, capColour = [45 35 30]; end        % took the cap off: dark hair
parts = { [0.00 0.45], 0.09, skin;  [0.45 0.55], 0.17, pl.shorts;
          [0.55 0.82], 0.20, pl.shirt;  [0.82 0.88], 0.06, skin;
          [0.88 0.96], 0.10, skin;  [0.96 1.00], 0.11, capColour };
right = cam.R(1, :);
for k = 1:size(parts, 1)
    z = parts{k, 1} * h;  hw = parts{k, 2};  col = parts{k, 3};
    P = [foot + [0 0 z(1)]; foot + [0 0 z(2)]];
    [px, ok] = tv.camera.project(cam, P);
    if ~all(ok), continue; end
    pw = tv.camera.project(cam, mean(P) + right * hw);
    half = max(1, norm(pw - tv.camera.project(cam, mean(P))));
    rows = round(min(px(:,2))):round(max(px(:,2)));
    rows = rows(rows >= 1 & rows <= cam.height);
    for rr = rows
        dv = px(2,2) - px(1,2);
        if abs(dv) < eps, f = 0; else, f = (rr - px(1,2)) / dv; end
        cx = px(1,1) + f * (px(2,1) - px(1,1));
        cols = max(1, round(cx - half)):min(cam.width, round(cx + half));
        for ch = 1:3, img(rr, cols, ch) = col(ch); end
    end
end
end
