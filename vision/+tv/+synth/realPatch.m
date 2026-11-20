function [F, bg, info] = realPatch(cond, d, c0, vel, ballRGB, frames, opts)
%REALPATCH  A ball's frames in a small patch with what real footage has round the ball (SYNTHETIC).
%   [F, bg, info] = tv.synth.realPatch(cond, d, c0, vel, ballRGB, frames, opts)
%   Chris, 22 Nov (item 12): the size study's pictures with the ball on the strings, passing heads,
%   bodies and racquets, shadows, HEVC at the camera's own bitrate, sensor noise that grows with the
%   light, and the rolling shutter. One patch opts.patch px square; the ball (diameter d px) passes
%   c0 at frame 0 moving vel px a frame. frames: the frame numbers wanted (e.g. [-8 -1 0 1 8]).
%   cond, what is round the ball:
%     'clear'         court (and sometimes a line) only
%     'ballShadow'    the ball's own shadow on the court, from on the ball (at the bounce) to a few
%                     diameters away, moving with it
%     'playerShadow'  a player's shadow edge across the court; in half the trials the ball is in the
%                     shade too (lit by the sky only: dark and bluish)
%     'strings'       a contact within 4 frames of frame 0: the ball comes in (from the other way,
%                     slower), meets the string bed and leaves at vel; the racquet head (rim and
%                     string bed) in front of a shirt, swinging through; the ball in front of the
%                     strings, or (half the trials: the other camera) seen through them
%     'bodyFront'     the ball passing in front of a body (shirts of several colours, one in ten
%                     close to the ball's own colour)
%     'bodyBehind'    a body or a head moving across the ball's path, covering part of it
%   Every frame: the scene, then sensor noise (read noise plus noise growing with the brightness),
%   then all the frames coded together with HEVC (libx265, 4:2:0) at a fixed quantiser opts.qp, after
%   opts.lead frames so the measured frames are coded from earlier ones as in a long recording.
%   opts.qp 23 is where x265 settles on whole 4K frames of the synthetic court with this noise at
%   240 Mb/s, the Mission 1 Pro's top bitrate (GoPro lists 240 Mb/s, H.265; 22 Nov). A patch cannot
%   be given the camera's bitrate directly: on a small, mostly still patch the rate control spends
%   a third of it. 29 stands in for a busier real scene or a weaker in-camera coder. bg: the static scene as the pipeline's
%   background would hold it (court, lines, a player's shadow; no moving things), coded the same way.
%   info.bpp: the bits per pixel per frame the coder spent on the patch. RETUNE(real footage): the
%   shares, colours and shapes here; opts.qp (from the real file's bitrate and its measured noise,
%   readNoise and shotGain, in still parts of Tuesday's first clip).
o = struct('patch', 160, 'fps', 240, 'shutter', 1 / 1920, 'readout', 0.008, 'cameraPx', [3840 2160], ...
    'qp', 23, 'readNoise', 1.5, 'shotGain', 0.03, 'lead', 6, 'jpegQ', 85, 'codec', 'hevc');
if nargin >= 7, for f = fieldnames(opts)', o.(f{1}) = opts.(f{1}); end, end
P = o.patch;
[X, Y] = meshgrid(1:P, 1:P);
m = d / 0.067;                                        % px per metre at the ball's distance
S = scene(cond, d, m, P, X, Y, c0, vel);
n0 = min(frames) - o.lead;  all_ = n0:max(frames);
rowT = o.readout / o.cameraPx(2) * o.fps;             % frames per image row (rolling shutter)
raw = zeros(P, P, 3, numel(all_));
for i = 1:numel(all_)
    raw(:, :, :, i) = render(S, all_(i), X, Y, d, c0, vel, ballRGB, o, rowT);
end
sig = sqrt(o.readNoise ^ 2 + o.shotGain * max(raw, 0));
noisy = uint8(min(max(raw + sig .* randn(size(raw)), 0), 255));
bgImg = uint8(min(max(S.static, 0), 255));
switch o.codec
    case 'hevc'
        [C, info.bpp] = code(cat(4, repmat(bgImg, 1, 1, 1, 3), noisy), o);
        bg = C(:, :, :, 3);  C = C(:, :, :, 4:end);
    otherwise                                          % 'none': for checking the scene alone
        C = noisy;  bg = bgImg;  info.bpp = NaN;
end
F = C(:, :, :, frames - n0 + 1);
info.cond = cond;
end

function S = scene(cond, d, m, P, X, Y, c0, vel)
% the static court (with a line in a third of the trials) and the layers round the ball
base = [40 90 160];  if rand() < 0.3, base = [170 95 70]; end
tex = imfilter(randn(P, P), fspecial('gaussian', 7, 1.5), 'replicate') * 12;
bg = repmat(reshape(base, 1, 1, 3), P, P) + repmat(tex, 1, 1, 3);
if rand() < 0.33
    a = rand() * pi;  off = (rand() - 0.5) * 40;  w = 3 + 4 * rand();
    dl = abs((X - P / 2) * sin(a) - (Y - P / 2) * cos(a) - off);
    ln = min(max(w / 2 + 0.5 - dl, 0), 1);
    bg = bg .* (1 - ln) + 235 * ln;
end
S = struct('path', @(n) c0 + vel .* n, 'cond', cond, 'static', bg, 'shade', ones(P, P), 'ballShade', [1 1 1], 'back', {{}}, 'front', {{}}, 'shadow', []);
shirts = [235 235 235; 30 30 35; 190 40 45; 40 70 150; 120 120 125; 196 150 120; 200 220 60];
pick = @() shirts(min(size(shirts, 1), 1 + floor(rand() * 6 + (rand() < 0.1) * 6)), :);   % one in ten: yellow-green
switch cond
    case 'playerShadow'
        a = rand() * pi;  off = (rand() - 0.5) * P / 2;
        s = (X - P / 2) * sin(a) - (Y - P / 2) * cos(a) - off;
        k = 0.45 + 0.15 * rand();                      % court brightness in the shade
        S.shade = 1 - (1 - k) * min(max(s + 0.5, 0), 1);
        S.static = S.static .* S.shade;
        if rand() < 0.5                               % the ball low and in the same shade
            S.ballShade = [0.35 0.40 0.55];
            % keep the ball inside: move the edge so that c0 is on the shaded side
            if (c0(1) - P / 2) * sin(a) - (c0(2) - P / 2) * cos(a) - off < 0
                S.shade = 1 - (1 - k) * min(max(-s + 0.5, 0), 1);
                S.static = bg .* S.shade;
            end
        end
    case 'ballShadow'
        dirn = deg2rad(90 + 60 * (2 * rand() - 1));   % below the ball in the picture, give or take
        S.shadow = struct('off', rand() * 4 * d * [cos(dirn), sin(dirn)], 'ax', d / 2 * [1, 1.6 + 0.4 * rand()], ...
            'ang', dirn, 'k', 0.45 + 0.15 * rand(), 'v', vel .* [1, 0.3]);
    case 'strings'
        sh = pick();
        body = layer(c0 + [0.1, 0.2] * m .* (2 * rand(1, 2) - 1), 0.25 * m * [1, 1.8], 0, sh, 1, vel * 0.08);
        nc = round(8 * rand() - 4);                   % the contact frame
        a = deg2rad(20 * (2 * rand() - 1));  Rm = [cos(a) -sin(a); sin(a) cos(a)];
        vin = -(0.6 + 0.3 * rand()) * vel * Rm';       % coming in: the other way, slower
        pc = c0 - vel * (0 - nc);  if nc > 0, pc = c0 - vin * (0 - nc); end   % where the contact is
        S.path = @(n) pc + (n >= nc) .* (vel .* (n - nc)) + (n < nc) .* (vin .* (n - nc));
        vr = vel * (0.5 + 0.3 * rand());              % the racquet swinging through
        cen0 = pc + (2 * rand(1, 2) - 1) * 0.04 * m - vr * nc;   % the ball near the bed's centre at contact
        ang = rand() * pi;
        bed = layer(cen0, [0.135, 0.16] * m, ang, [215 215 210], 0.22, vr);
        rimC = [25 25 30];  if rand() < 0.5, rimC = [200 40 40] .* (0.6 + 0.4 * rand()); end
        rim = layer(cen0, [0.135, 0.16] * m + 0.012 * m, ang, rimC, 1, vr);  rim.ring = 0.02 * m;
        if rand() < 0.5
            S.back = {body, rim, bed};                % the ball in front of the strings
        else
            S.back = {body};  S.front = {rim, bed};   % the other camera: seen through them
        end
    case 'bodyFront'
        S.back = {layer(c0 + 0.2 * m * (2 * rand(1, 2) - 1), 0.25 * m * [1, 1.8], 0, pick(), 1, vel * 0.1 .* (2 * rand(1, 2) - 1))};
    case 'bodyBehind'
        if rand() < 0.5
            ax = 0.25 * m * [1, 1.8];  col = pick();    % a body
        else
            ax = 0.11 * m * [1, 1.15];  col = [45 35 30];  if rand() < 0.4, col = [196 150 120]; end   % a head: hair or face
        end
        % its edge across the path near frame 0: the ball partly behind it
        u = vel / max(norm(vel), eps);  nrm = [-u(2), u(1)];
        rEdge = 1 / sqrt((nrm(1) / ax(1)) ^ 2 + (nrm(2) / ax(2)) ^ 2);   % centre to edge along nrm
        cen = c0 + nrm * (rEdge + d * (rand() - 0.5)) * sign(rand() - 0.5);  % edge within d/2 of the ball's centre
        S.front = {layer(cen, ax, 0, col, 1, vel * 0.1 .* (2 * rand(1, 2) - 1))};
end
end

function L = layer(c, ax, ang, rgb, alpha, v)
L = struct('c', c, 'ax', ax, 'ang', ang, 'rgb', rgb, 'alpha', alpha, 'v', v, 'ring', 0);
end

function img = render(S, n, X, Y, d, c0, vel, ballRGB, o, rowT)
img = S.static;
for i = 1:numel(S.back), img = paint(img, S.back{i}, n, X, Y); end
if ~isempty(S.shadow)
    sh = S.shadow;  c = c0 + sh.off + sh.v * n;
    a = ellipse(X, Y, c, sh.ax, sh.ang);
    img = img .* (1 - (1 - sh.k) * a);
end
% the ball: five instants across the shutter; each row at its own time (rolling shutter)
cover = zeros(size(X));
pn = S.path(n);
tRow = (Y - pn(2)) * rowT;                            % rows below the ball's row are read later
for s = linspace(-0.5, 0.5, 5)
    tt = n + tRow + s * o.shutter * o.fps;            % frames
    c = S.path(tt(:));
    cx = reshape(c(:, 1), size(X));  cy = reshape(c(:, 2), size(X));
    cover = cover + min(max(d / 2 + 0.5 - hypot(X - cx, Y - cy), 0), 1) / 5;
end
col = reshape(ballRGB .* S.ballShade, 1, 1, 3);
under = 1 - 0.18 * min(max((Y - pn(2)) / max(d / 2, 1), 0), 1);   % darker underneath
img = img .* (1 - cover) + col .* under .* cover;
for i = 1:numel(S.front), img = paint(img, S.front{i}, n, X, Y); end
end

function img = paint(img, L, n, X, Y)
c = L.c + L.v * n;
a = ellipse(X, Y, c, L.ax, L.ang);
if L.ring > 0, a = a .* (1 - ellipse(X, Y, c, L.ax - L.ring, L.ang)); end
a = a * L.alpha;
img = img .* (1 - a) + reshape(L.rgb, 1, 1, 3) .* a;
end

function a = ellipse(X, Y, c, ax, ang)
% soft-edged filled ellipse (about one pixel of edge)
dx = X - c(1);  dy = Y - c(2);
u = dx * cos(ang) + dy * sin(ang);  w = -dx * sin(ang) + dy * cos(ang);
r = sqrt((u / max(ax(1), 0.5)) .^ 2 + (w / max(ax(2), 0.5)) .^ 2);
a = min(max((1 - r) * min(ax) + 0.5, 0), 1);
end

function [C, bpp] = code(F, o)
% all frames through HEVC at the camera's bits per pixel, and back
[H, W, ~, N] = size(F);
t = tempname();  raw = [t '.rgb'];  mp4 = [t '.mp4'];  back = [t '_b.rgb'];
fid = fopen(raw, 'w');  fwrite(fid, permute(F, [3 2 1 4]), 'uint8');  fclose(fid);
ff = tv.util.ffmpeg();
tv.util.run(sprintf(['%s -y -v error -f rawvideo -pix_fmt rgb24 -s %dx%d -r %d -i "%s" -c:v libx265 -preset ultrafast ' ...
    '-x265-params log-level=error:keyint=240:min-keyint=240:qp=%d -pix_fmt yuv420p "%s"'], ff, W, H, o.fps, raw, o.qp, mp4));
tv.util.run(sprintf('%s -y -v error -i "%s" -f rawvideo -pix_fmt rgb24 "%s"', ff, mp4, back));
dd = dir(mp4);  bpp = dd.bytes * 8 / (H * W * N);
fid = fopen(back, 'r');  v = fread(fid, inf, 'uint8=>uint8');  fclose(fid);
delete(raw);  delete(mp4);  delete(back);
C = permute(reshape(v(1:H * W * 3 * N), 3, W, H, N), [3 2 1 4]);
end
