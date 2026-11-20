function reel(outDir, R)
%REEL  Rallies-only reel and one clip per rally, from camera 1 (TV-RAL-04).
%   Cut with FFmpeg; NVIDIA's encoder when there is a GPU, else the CPU
%   encoder (same output, slower). At most 1080 lines high.
d = fullfile(outDir, 'clips');
if ~exist(d, 'dir'), mkdir(d); end
src = R.rec(1).file;
h = min(1080, R.rec(1).height);
list = fullfile(d, 'list.txt');
fid = fopen(list, 'w');
for r = 1:size(R.rallyWindows, 1)
    w = R.rallyWindows(r, :);
    clip = fullfile(d, sprintf('rally_%02d.mp4', r));
    args = sprintf('-ss %.3f -t %.3f %s -vf scale=-2:%d -c:a aac', w(1), w(2) - w(1), tv.media.inputArgs(src), h);
    ok = false;
    if tv.util.useGpu()
        st = tv.util.shell(sprintf('%s -y -v error %s -c:v h264_nvenc -preset p5 -cq 23 "%s"', tv.util.ffmpeg(), args, clip));
        ok = st == 0;
    end
    if ~ok
        tv.util.run(sprintf('%s -y -v error %s -c:v libx264 -preset veryfast -crf 23 "%s"', tv.util.ffmpeg(), args, clip));
    end
    [~, nm, ex] = fileparts(clip);                      % FFmpeg reads names relative to the list
    fprintf(fid, 'file ''%s''\n', [nm ex]);
end
fclose(fid);
tv.util.run(sprintf('%s -y -v error -f concat -safe 0 -i "%s" -c copy "%s"', tv.util.ffmpeg(), list, fullfile(outDir, 'reel_1080p.mp4')));
delete(list);
end
