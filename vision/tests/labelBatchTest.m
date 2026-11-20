% The phone labelling batch (Chris, 22 Nov, item 13): candidates from a processed clip, ranked,
% at most 5 a rally, sized for the time given; the full frame, the crop and the frames round it.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'tools'));

%% A batch from a made-up result: sizes, sources and the pictures
d = tempname();  mkdir(d);
f = fullfile(d, 'clip.mp4');
tv.util.run(sprintf('%s -y -v error -f lavfi -i testsrc2=size=640x360:rate=240:duration=1 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "%s"', tv.util.ffmpeg(), f));
info = tv.media.probe(f);
tv.util.seed(3);
cand = cell(2, 2);  tracks = cell(2, 2);
for ra = 1:2
    for k = 1:2
        n = 40;  fr = (60 * ra + (0:n - 1))';
        cand{ra, k} = [fr, 100 + 3 * (0:n - 1)', 150 + 0 * fr, rand(n, 1), 4 * ones(n, 1), 8 * ones(n, 1)];
        tracks{ra, k} = struct('frames', fr(1:20), 'uv', [100 + 3 * (0:19)', 150 + 0 * (0:19)']);
    end
end
gl = struct('cam', {1, 1, 2}, 'track', {5, 5, 6}, 'frame', {70, 71, 90}, 'u', {300, 302, 400}, 'v', {100, 100, 200}, 'reason', {'outside the court', 'outside the court', 'not on its own path'});
res = struct('name', 'clip2', 'rec', [info info], 'candidates', {cand}, 'ballTracks', {tracks}, 'gateLog', {{gl; gl([])}}, 'dropped', {{[]; []}});
out = fullfile(d, 'batch');
B = labelBatch(res, out, struct('minutes', 1, 'secondsEach', 6, 'neighbours', 2));
assert(B.n == 10, 'sized for one minute at 6 s each: %d', B.n)
ra = [B.candidates.rally];
assert(all(histc(ra, 1:2) <= 5), 'at most 5 a rally')
src = unique({B.candidates.source});
assert(any(strcmp(src, 'lost')), 'losses rank high: %s', strjoin(src, ', '))
B2 = labelBatch(res, fullfile(d, 'batch2'), struct('minutes', 5, 'secondsEach', 6, 'neighbours', 0, 'perRally', 40));
assert(all(ismember({'lost', 'conflict', 'rejected', 'uncertain'}, unique({B2.candidates.source}))), 'every source drawn on')
J = jsondecode(fileread(fullfile(out, 'batch.json')));
assert(J.n == B.n && numel(J.candidates) == B.n)
c1 = J.candidates(1);  if iscell(c1), c1 = c1{1}; end
im = imread(fullfile(out, c1.full));  cr = imread(fullfile(out, c1.crop));
assert(size(im, 2) == 1920 && size(cr, 1) <= 256 && size(cr, 2) <= 256)
assert(numel(c1.neighbours) == 4 && exist(fullfile(out, c1.neighbours(1).file), 'file') == 2)
fprintf('batch: %d candidates, sources %s\n', B.n, strjoin(src, ', '));
