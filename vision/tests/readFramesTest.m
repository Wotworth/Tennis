% Frames through memory (Chris, 22 Nov, item 8): read from FFmpeg's pipe, they are the same frames
% as through the temporary file.

%% The pipe and the file give the same frames
d = tempname();  mkdir(d);
f = fullfile(d, 'clip.mp4');
tv.util.run(sprintf('%s -y -v error -f lavfi -i testsrc2=size=320x180:rate=240000/1001:duration=1 -c:v libx264 -preset ultrafast -g 24 -pix_fmt yuv420p "%s"', tv.util.ffmpeg(), f));
info = tv.media.probe(f);
setenv('TV_FRAMES_FILE', '1');  [A, h1] = tv.media.readFrames(info, 100, 12);  As = tv.media.readFrames(info, 100, 5, 0.5);
setenv('TV_FRAMES_FILE', '');   [B, h2] = tv.media.readFrames(info, 100, 12);  [Bs, h3] = tv.media.readFrames(info, 100, 5, 0.5);
fprintf('%s %s, %s %s\n', h1, mat2str(size(A)), h2, mat2str(size(B)));
assert(strcmp(h1, 'file') && strcmp(h2, 'pipe') && strcmp(h3, 'pipe'), 'the pipe was not used')
assert(isequal(A, B) && isequal(As, Bs))
C = tv.media.readFrames(info, info.nFrames - 3, 10);     % past the end: what there is
assert(size(C, 4) == 3)
