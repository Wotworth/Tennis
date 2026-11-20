% A recording GoPro split into chapters is read as one (tv.media.joinChapters; Chris, 22 Nov: found by
% the dress rehearsal: only the first chapter of each recording reached the pipeline).

%% Two chapters read as the whole: frame count, continuous frame times, the same pictures
d = tempname();  mkdir(d);
ff = tv.util.ffmpeg();
whole = fullfile(d, 'whole.mp4');
tv.util.run(sprintf(['%s -y -v error -f lavfi -i testsrc2=size=320x180:rate=240000/1001:duration=2 -f lavfi -i sine=d=2 ' ...
    '-c:v libx264 -preset ultrafast -g 24 -pix_fmt yuv420p -c:a aac -shortest -metadata creation_time=2026-11-25T15:00:00Z -timecode 15:00:00:00 "%s"'], ff, whole));
c1 = fullfile(d, 'GX010042.MP4');  c2 = fullfile(d, 'GX020042.MP4');
tv.util.run(sprintf('%s -y -v error -i "%s" -frames:v 240 -c:v libx264 -preset ultrafast -g 24 -pix_fmt yuv420p -c:a aac -timecode 15:00:00:00 -metadata creation_time=2026-11-25T15:00:00Z "%s"', ff, whole, c1));
tv.util.run(sprintf('%s -y -v error -ss %.6f -i "%s" -c:v libx264 -preset ultrafast -g 24 -pix_fmt yuv420p -c:a aac "%s"', ff, 240 * 1001 / 240000, whole, c2));
g = tv.ingest.chapters({'GX020042.MP4', 'GX010042.MP4'});
assert(numel(g) == 1 && strcmp(g.files{1}, 'GX010042.MP4'))
list = tv.media.joinChapters(fullfile(d, g.files));
assert(~isempty(strfind(list, '.ffconcat')))
I = tv.media.probe(list);  A = tv.media.probe(c1);  B = tv.media.probe(c2);
fprintf('chapters %d + %d frames, read as %d; start %s\n', A.nFrames, B.nFrames, I.nFrames, I.startUtc);
assert(I.nFrames == A.nFrames + B.nFrames)
assert(all(diff(I.pts) > 0) && abs(max(diff(I.pts)) - 1001 / 240000) < 1e-4)   % no gap or overlap at the join
assert(strcmp(I.startUtc, A.startUtc))
f = A.nFrames + 10;                                       % a frame in chapter 2
x = double(tv.media.readFrames(I, f, 1));  y = double(tv.media.readFrames(B, 10, 1));
assert(mean(abs(x(:) - y(:))) < 2)
assert(strcmp(tv.media.joinChapters({c1}), c1))           % one chapter: the file itself
