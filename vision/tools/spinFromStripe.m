function R = spinFromStripe(file, opts)
%SPINFROMSTRIPE  Spin truth from marked balls filmed side-on as they leave the machine (Chris, 22 Nov, item 6).
%   R = spinFromStripe('GH010123.MP4')
%   Tuesday's optional spin test (manual 16.3): six balls with a thick stripe round them and a dot on
%   one side, fed by the machine, filmed by the Hero 7 at 1080p240 from about 3 m, side-on (looking
%   along the spin axis, so the spin shows as the ball's picture turning). For each ball:
%     1. the ball is found in every frame it is in view: what differs from the clip's still
%        background, yellow-green, ball-sized; frames in a row make one ball's pass
%     2. each frame's picture of the ball is unwrapped round its centre (angle by distance from the
%        centre), and the turn from one frame to the next is the shift that best lines the two up
%        (the dot makes a whole turn tell apart from half a turn)
%     3. rpm = the slope of the angle turned so far against the frame number x frames a second /
%        360 x 60; the scatter about that line gives its uncertainty. Turns over 150 degrees a frame (over 6000 rpm at 240
%        frames a second) cannot be told from the other way round and are flagged.
%   R.balls(i): firstFrame, nFrames, rpm, rpmSd, degPerFrame (each pair), sizePx, aliased.
%   opts: fps (default: the file's), maxBalls, minFrames (default 6), diffThresh.
%   The camera counts frames, not time: the rpm is as good as its frame rate (240: 0.1%).
if nargin < 2, opts = struct(); end
d = struct('fps', NaN, 'minFrames', 6, 'diffThresh', 40, 'maxSeconds', 120, 'nAngles', 180, 'scale', 1);
for f = fieldnames(d)', if ~isfield(opts, f{1}), opts.(f{1}) = d.(f{1}); end, end
info = tv.media.probe(file);
fps = opts.fps;  if ~isfinite(fps), fps = info.fps; end
n = min(info.nFrames, round(opts.maxSeconds * fps));
% the still background: the median of frames spread over the clip
idx = round(linspace(0, n - 1, min(25, n)));
S = zeros(info.height, info.width, 3, numel(idx), 'uint8');
for i = 1:numel(idx), S(:, :, :, i) = tv.media.readFrames(info, idx(i), 1); end
bg = double(median(S, 4));
% every frame: the ball's blob
found = nan(n, 3);                                   % x, y, radius
crops = cell(n, 1);
chunk = 240;
for f0 = 0:chunk:n - 1
    F = tv.media.readFrames(info, f0, min(chunk, n - f0));
    for j = 1:size(F, 4)
        [b, c] = ballIn(double(F(:, :, :, j)), bg, opts);
        if ~isempty(b), found(f0 + j, :) = b;  crops{f0 + j} = c; end
    end
end
% passes: frames in a row with a ball
has = isfinite(found(:, 1));
starts = find(has & [true; ~has(1:end - 1)]);
R.balls = struct('firstFrame', {}, 'nFrames', {}, 'rpm', {}, 'rpmSd', {}, 'degPerFrame', {}, 'sizePx', {}, 'aliased', {});
R.fps = fps;  R.file = file;
for s = starts(:)'
    e = s;  while e < n && has(e + 1), e = e + 1; end
    if e - s + 1 < opts.minFrames, continue; end
    dth = nan(e - s, 1);
    for k = s:e - 1
        dth(k - s + 1) = turn(crops{k}, crops{k + 1}, opts.nAngles);
    end
    dth = dth(isfinite(dth));
    if isempty(dth), continue; end
    % the angle turned so far, frame by frame (signs agreeing with the main direction), and the
    % straight line through it: its slope is the turn per frame, its scatter the uncertainty
    sg = sign(median(dth));  if sg == 0, sg = 1; end
    a = abs(dth);  a(sign(dth) ~= sg) = NaN;  a = a(isfinite(a));
    if numel(a) < 3, continue; end
    cum = [0; cumsum(a)];  t = (0:numel(a))';
    p = [t, ones(size(t))] \ cum;
    res = cum - [t, ones(size(t))] * p;
    rpm = p(1) * fps / 360 * 60;
    sd = sqrt(sum(res .^ 2) / max(1, numel(t) - 2) / sum((t - mean(t)) .^ 2)) * fps / 360 * 60;
    R.balls(end+1) = struct('firstFrame', s - 1, 'nFrames', e - s + 1, 'rpm', rpm, 'rpmSd', sd, ...
        'degPerFrame', dth', 'sizePx', 2 * median(found(s:e, 3)), 'aliased', p(1) > 150); %#ok<AGROW>
end
end

function [b, crop] = ballIn(img, bg, opts)
% the largest ball-coloured blob that differs from the background, and its unwrapped picture
b = [];  crop = [];
dif = sum(abs(img - bg), 3);
r = img(:, :, 1);  g = img(:, :, 2);  bl = img(:, :, 3);
yellow = g > bl + 30 & r > bl;                          % optic yellow-green: blue well below red and green
mk = dif > opts.diffThresh & (yellow | dif > 3 * opts.diffThresh);
mk = imclose(mk, strel('disk', 2, 0));
mk = imfill(mk, 'holes');
CC = bwconncomp(mk);
if CC.NumObjects == 0, return; end
P = regionprops(CC, 'Area', 'Centroid', 'Eccentricity');
ok = [P.Area] >= 20 & [P.Eccentricity] < 0.9;
if ~any(ok), return; end
[~, k] = max([P.Area] .* ok);
c = P(k).Centroid;  rad = sqrt(P(k).Area / pi);
b = [c, rad];
crop = unwrap(mean(img, 3), c, rad);
end

function U = unwrap(gray, c, rad)
% the ball's picture by angle (columns, 0..360) and distance from the centre (rows, 0.15..0.85 r):
% brightness relative to the ball's own mean, so the light and the blur matter less
na = 180;  rr = linspace(0.15, 0.85, 8)' * rad;  th = (0:na - 1) * 2 * pi / na;
X = c(1) + rr * cos(th);  Y = c(2) + rr * sin(th);
U = interp2(gray, X, Y, 'linear', NaN);
v = U(isfinite(U));  if isempty(v), v = 0; end
U = U - mean(v);  U(~isfinite(U)) = 0;
s = sqrt(mean(U(:) .^ 2));  if s > 0, U = U / s; end
end

function d = turn(A, B, na)
% the turn (degrees, -180..180) that lines picture B up with picture A: circular correlation along the angle
d = NaN;
if isempty(A) || isempty(B), return; end
FA = fft(A, [], 2);  FB = fft(B, [], 2);
c = real(ifft(sum(conj(FA) .* FB, 1)));
[~, k] = max(c);
% sub-step: a parabola through the peak and its neighbours
km = mod(k - 2, na) + 1;  kp = mod(k, na) + 1;
den = c(km) - 2 * c(k) + c(kp);  off = 0;
if den < 0, off = 0.5 * (c(km) - c(kp)) / den; end
d = (k - 1 + off) * 360 / na;
if d > 180, d = d - 360; end
end
