function files = fakeCard(root, serial, startUtc, numbers, seconds)
%FAKECARD  A pretend GoPro SD card for the ingest tests (TV-ING tests).
%   root/DCIM/100GOPRO/ with, for each recording number, a small MP4
%   (GX01nnnn.MP4: test pattern, sound, creation time, timecode, the serial
%   in the comment tag), its low-resolution copy (GL01nnnn.LRV) and a
%   thumbnail (GX01nnnn.THM). Recording k starts startUtc + (k-1)*(seconds+5).
if nargin < 4, numbers = 1; end
if nargin < 5, seconds = 2; end
d = fullfile(root, 'DCIM', '100GOPRO');
if ~exist(d, 'dir'), mkdir(d); end
files = {};
for i = 1:numel(numbers)
    n = numbers(i);
    t = tv.util.utcPlus(startUtc, (i - 1) * (seconds + 5));
    mp4 = fullfile(d, sprintf('GX01%04d.MP4', n));
    tv.util.run(sprintf(['%s -y -v error -f lavfi -i testsrc=size=160x90:rate=30 -f lavfi -i sine=frequency=440 ' ...
        '-t %g -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest -metadata creation_time=%s ' ...
        '-metadata comment="serial=%s" -timecode %s "%s"'], tv.util.ffmpeg(), seconds, t, serial, ...
        tv.util.timecode(t, 30), mp4));
    copyfile(mp4, fullfile(d, sprintf('GL01%04d.LRV', n)));
    tv.util.run(sprintf('%s -y -v error -i "%s" -frames:v 1 "%s"', tv.util.ffmpeg(), mp4, ...
        fullfile(d, sprintf('GX01%04d.jpg', n))));
    movefile(fullfile(d, sprintf('GX01%04d.jpg', n)), fullfile(d, sprintf('GX01%04d.THM', n)));
    files{end+1} = mp4; %#ok<AGROW>
end
end
