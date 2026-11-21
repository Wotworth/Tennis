function R = spinFromStripe(file, opts)
%SPINFROMSTRIPE  Spin truth from marked balls filmed side-on as they leave the machine (Chris, 22 Nov, item 6).
%   R = spinFromStripe('GH010123.MP4')
%   Tuesday's optional spin test (manual 16.3): six balls with a thick stripe round them and a dot on
%   one side, fed by the machine, filmed by the Hero 7 at 1080p240 from about 3 m, side-on (looking
%   along the spin axis, so the spin shows as the ball's picture turning). For each ball:
%     1. the ball is found in every frame it is in view: what differs from the clip's still
%        background, yellow-green, ball-sized; frames in a row make one ball's pass
%     2. each frame's picture of the ball is unwrapped round its centre (angle by distance from the
%        centre); the turn between two pictures is the shift that best lines them up
%     3. the turn per frame up to a half turn comes from every pair of frames in a row together
%        (the band alone looks the same after half a turn). Which of the two: the way the ball spins
%        when it is known (opts.spin 'top' or 'back', with the way the ball crosses the picture;
%        the two readings always turn opposite ways), else the dot's evidence over the whole pass.
%        The dot tells little when it sits near the spin axis, facing the camera: then sense is
%        'unsure'.
%     4. every frame's angle is measured against the pass's middle frame and followed outwards;
%        rpm = the slope of the straight line through them x frames a second / 360 x 60, and the
%        scatter about the line gives rpmSd. Turns over 150 degrees a frame (over 6000 rpm at 240
%        frames a second) are flagged as aliased.
%   R.balls(i): firstFrame, nFrames, rpm, rpmSd, degPerFrame (each pair in a row), sizePx, aliased,
%   sense ('given', 'dot' or 'unsure').
%   opts: fps (default: the file's), spin ('top', 'back' or ''), minFrames (default 6), diffThresh.
%   The camera counts frames, not time: the rpm is as good as its frame rate (240: 0.1%).
if nargin < 2, opts = struct(); end
d = struct('fps', NaN, 'spin', '', 'minFrames', 6, 'diffThresh', 40, 'maxSeconds', 120, 'nAngles', 180, 'scale', 1);
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
R.balls = struct('firstFrame', {}, 'nFrames', {}, 'rpm', {}, 'rpmSd', {}, 'degPerFrame', {}, 'sizePx', {}, 'aliased', {}, 'sense', {});
R.fps = fps;  R.file = file;
for s = starts(:)'
    e = s;  while e < n && has(e + 1), e = e + 1; end
    if e - s + 1 < opts.minFrames, continue; end
    na = opts.nAngles;  step = 360 / na;  w = round(na / 6);
    % (a) each pair of frames in a row: its circular correlation along the angle
    C = nan(e - s, na);
    for k = s:e - 1
        C(k - s + 1, :) = corrAlong(crops{k}, crops{k + 1});
    end
    C = C(all(isfinite(C), 2), :);
    if size(C, 1) < 3, continue; end
    % (b) the turn per frame up to a half turn: the band repeats every half turn, so the two halves
    % of the correlation are added, over every pair of the pass
    [~, h] = max(sum(C(:, 1:na / 2) + C(:, na / 2 + 1:end), 1));
    dA = (h - 1) * step;  if dA > 180, dA = dA - 360; end
    dB = dA - 180 * sign(dA + (dA == 0));
    % (c) which of the two: the way the ball spins when it is known (opts.spin, with the way it
    % moves across the picture), else the dot's evidence over every pair; too little evidence is
    % flagged. On the picture, topspin turns clockwise for a ball moving right, anticlockwise left.
    ev = C(:, h) - C(:, mod(h - 1 + na / 2, na) + 1);
    tEv = mean(ev) / (std(ev) / sqrt(numel(ev)) + eps);
    dx = found(e, 1) - found(s, 1);
    if any(strcmp(opts.spin, {'top', 'back'})) && dx ~= 0
        want = sign(dx) * (2 * strcmp(opts.spin, 'top') - 1);
        if sign(dA) == want, d0 = dA; else, d0 = dB; end
        sense = 'given';
    else
        if tEv >= 0, d0 = dA; else, d0 = dB; end
        sense = tv.testing.ternary(abs(tEv) >= 3, 'dot', 'unsure');
    end
    k0 = mod(round(d0 / step), na) + 1;
    % (d) each pair's own turn near the pass's (for the record and the prediction below)
    dth = nan(size(C, 1), 1);
    for i = 1:size(C, 1), dth(i) = peakNear(C(i, :), k0, w) * step; end
    dth(dth > 180) = dth(dth > 180) - 360;
    md = median(dth);  d1 = mean(dth(abs(dth - md) <= max(10, 3 * 1.4826 * median(abs(dth - md)))));
    % (e) the angle of every frame against the middle frame of the pass, followed frame by frame
    % from the middle outwards; a straight line through those angles has the turn per frame as its
    % slope. Each frame's angle carries its own error only, so the slope is much better than the
    % frame-to-frame turns, and its scatter gives an honest uncertainty.
    ref = s + floor((e - s) / 2);  th = nan(e - s + 1, 1);  th(ref - s + 1) = 0;
    for dirn = [1 -1]
        last = 0;  jl = ref;
        for j = ref + dirn:dirn:tv.testing.ternary(dirn > 0, e, s)
            c = corrAlong(crops{ref}, crops{j});
            if ~all(isfinite(c)), continue; end
            pred = last + (j - jl) * d1;
            m = peakNear(c, mod(round(pred / step), na) + 1, w) * step;
            v = pred + mod(m - pred + 180, 360) - 180;
            th(j - s + 1) = v;
            if abs(v - pred) < 25, last = v;  jl = j; end
        end
    end
    t = (0:e - s)';  ok = isfinite(th);
    for pass2 = 1:2
        X = [t(ok), ones(nnz(ok), 1)];  p = X \ th(ok);  res = th - [t, ones(size(t))] * p;
        if pass2 == 1
            mr = median(abs(res(ok)));  ok = ok & abs(res) <= max(6, 3 * 1.4826 * mr);
            if nnz(ok) < 4, break; end
        end
    end
    if nnz(ok) < 4, continue; end
    rpm = abs(p(1)) * fps / 360 * 60;
    sd = sqrt(sum(res(ok) .^ 2) / max(1, nnz(ok) - 2) / sum((t(ok) - mean(t(ok))) .^ 2)) * fps / 360 * 60;
    R.balls(end+1) = struct('firstFrame', s - 1, 'nFrames', e - s + 1, 'rpm', rpm, 'rpmSd', sd, ...
        'degPerFrame', dth', 'sizePx', 2 * median(found(s:e, 3)), 'aliased', abs(p(1)) > 150, 'sense', sense); %#ok<AGROW>
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

function c = corrAlong(A, B)
% circular correlation along the angle between pictures A and B (NaN when either is missing):
% c(k) is how well B matches A turned by (k - 1) steps
if isempty(A) || isempty(B), c = NaN; return; end
FA = fft(A, [], 2);  FB = fft(B, [], 2);
c = real(ifft(sum(conj(FA) .* FB, 1)));
end

function k = peakNear(c, k0, w)
% the correlation peak within w steps of step k0 (circular), with a parabola through it and its
% neighbours for the sub-step; returned as a step count from 0
na = numel(c);  idx = mod(k0 - 1 + (-w:w), na) + 1;
[~, j] = max(c(idx));  kk = idx(j);
km = mod(kk - 2, na) + 1;  kp = mod(kk, na) + 1;
den = c(km) - 2 * c(kk) + c(kp);  off = 0;
if den < 0, off = 0.5 * (c(km) - c(kp)) / den; end
k = mod(kk - 1 + off, na);
end
