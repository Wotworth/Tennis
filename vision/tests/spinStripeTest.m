% Spin truth from striped balls (Chris, 22 Nov, item 6): a made-up Hero 7 clip at 240 frames a
% second, balls 13 px across with a stripe round them and a dot, each turning at a known rate as it
% crosses the picture; tools/spinFromStripe.m finds each ball and its rpm.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'tools'));

%% Four balls, 1200 to 4800 rpm, through H.264
W = 480;  H = 270;  fps = 240;  diam = 13;  r = diam / 2;
rpms = [1200 2400 3600 4800];
tv.util.seed(5);
court = repmat(reshape([60 120 70], 1, 1, 3), H, W) + 6 * randn(H, W, 3);
d = tempname();  mkdir(d);  raw = fullfile(d, 'c.rgb');  f = fullfile(d, 'GH010001.MP4');
fid = fopen(raw, 'w');
[X, Y] = meshgrid(1:W, 1:H);
gap = 30;  pass = 40;                                 % frames between balls, frames in view
nT = numel(rpms) * (pass + gap) + gap;
for n = 0:nT - 1
    img = court;
    b = floor((n - gap) / (pass + gap)) + 1;  k = n - gap - (b - 1) * (pass + gap);
    if b >= 1 && b <= numel(rpms) && k >= 0 && k < pass
        cx = 40 + k * (W - 80) / pass;  cy = 140 - 30 * k / pass;
        nrm = [sin(0.4 * b), 0.3, cos(0.4 * b)];  nrm = nrm / norm(nrm);   % the stripe's plane, fixed in the ball
        dotc = cross(nrm, [0 1 0]);  dotc = dotc / norm(dotc);            % the dot: on the stripe's side
        acc = zeros(H, W);  cov = zeros(H, W);
        for s = linspace(-0.5, 0.5, 3)                                  % shutter 1/960 s: blur
            th = 2 * pi * rpms(b) / 60 * (k + s * 0.25) / fps;
            u = (X - cx) / r;  v = (Y - cy) / r;  in = u .^ 2 + v .^ 2 < 1;
            w = sqrt(max(0, 1 - u .^ 2 - v .^ 2));
            ub = cos(th) * u + sin(th) * v;  vb = -sin(th) * u + cos(th) * v;   % into the ball's own frame
            p = [ub(:), vb(:), w(:)];
            mark = abs(p * nrm') < 0.22 | acos(min(1, p * dotc')) < 0.45;
            shade = 230 - 140 * reshape(mark, H, W);
            acc = acc + in .* shade / 3;  cov = cov + in / 3;
        end
        for ch = 1:3
            col = [1 1.02 0.25];
            img(:, :, ch) = img(:, :, ch) .* (1 - cov) + acc * col(ch);
        end
    end
    fwrite(fid, permute(uint8(min(max(img + 2 * randn(H, W, 3), 0), 255)), [3 2 1]), 'uint8');
end
fclose(fid);
tv.util.run(sprintf('%s -y -v error -f rawvideo -pix_fmt rgb24 -s %dx%d -r %d -i "%s" -c:v libx264 -crf 18 -pix_fmt yuv420p "%s"', tv.util.ffmpeg(), W, H, fps, raw, f));
% the machine is set to topspin; the balls cross the picture left to right
R = spinFromStripe(f, struct('spin', 'top'));
fprintf('found %d balls: %s rpm, sd %s (truth %s)\n', numel(R.balls), mat2str(round([R.balls.rpm])), mat2str(round(10 * [R.balls.rpmSd]) / 10), mat2str(rpms));
assert(numel(R.balls) == numel(rpms))
err = [R.balls.rpm] - rpms;
assert(all(abs(err) ./ rpms < 0.02), 'rpm off by more than 2%')
assert(all(abs(err) <= 3 * [R.balls.rpmSd] + 0.002 * rpms), 'the stated uncertainty does not cover the error')
% without the machine's setting the dot decides; where it can't, the ball must say so
R2 = spinFromStripe(f);
fprintf('without the setting: %s rpm, %s\n', mat2str(round([R2.balls.rpm])), strjoin({R2.balls.sense}, ', '));
assert(numel(R2.balls) == numel(rpms))
assert(all(abs([R2.balls.rpm] - rpms) ./ rpms < 0.02 | strcmp({R2.balls.sense}, 'unsure')), 'a wrong half turn was not flagged')
