function file = writeRecording(folder, cam, sc, truth, k)
%WRITERECORDING  Render camera k's footage and write it as a GoPro-like MP4.
%   Frames go to FFmpeg in chunks (H.264, yuv420p, 119.88 fps), the chunks
%   are joined without re-encoding, and the sound and metadata are added:
%   creation_time (the camera's start, with sc.coarseError added, as a real
%   clock would be off), a timecode, and the camera serial in the comment
%   tag (real files carry it in the GPMF track; see tv.ingest).
%   The file is named like a GoPro file: GX01<4 digits>.MP4.
if ~exist(folder, 'dir'), mkdir(folder); end
tmp = tempname();  mkdir(tmp);
cleanup = onCleanup(@() rmdirQuiet(tmp));
bg = tv.synth.renderBackground(cam, sc);
nFrames = floor((sc.duration - cam.recordStart - 0.05) * cam.fps);
chunk = 240;  parts = {};
ff = tv.util.ffmpeg();
for c0 = 0:chunk:nFrames - 1
    raw = fullfile(tmp, sprintf('c%05d.rgb', c0));
    fid = fopen(raw, 'w');
    for n = c0:min(nFrames, c0 + chunk) - 1
        img = tv.synth.renderFrame(cam, bg, sc, truth, n, sc.seed * 1000 + k * 100000);
        fwrite(fid, permute(img, [3 2 1]), 'uint8');      % rgb24, row by row
    end
    fclose(fid);
    part = fullfile(tmp, sprintf('c%05d.mp4', c0));
    tv.util.run(sprintf(['%s -y -v error -f rawvideo -pix_fmt rgb24 -s %dx%d -r 120000/1001 -i "%s" ' ...
        '-c:v libx264 -preset veryfast -crf %d -g 30 -pix_fmt yuv420p "%s"'], ff, cam.width, cam.height, raw, sc.crf, part));
    delete(raw);
    parts{end+1} = part; %#ok<AGROW>
end
list = fullfile(tmp, 'list.txt');
fid = fopen(list, 'w');
for i = 1:numel(parts), fprintf(fid, 'file ''%s''\n', parts{i}); end
fclose(fid);
[y, fs] = tv.synth.renderAudio(cam, sc, truth);
wav = fullfile(tmp, 'a.wav');
audiowrite(wav, y((round(max(0, cam.recordStart) * fs) + 1):end), fs);
startUtc = tv.util.utcPlus(sc.utcStart, tv.synth.truthTime(cam, cam.recordStart) + sc.coarseError(k));
file = fullfile(folder, sprintf('GX01%04d.MP4', 10 + k));
tv.util.run(sprintf(['%s -y -v error -f concat -safe 0 -i "%s" -i "%s" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k ' ...
    '-metadata creation_time=%s -metadata comment="serial=%s" -timecode %s "%s"'], ...
    ff, list, wav, startUtc, cam.serial, tv.util.timecode(startUtc, cam.fps), file));
end

function rmdirQuiet(d)
try, rmdir(d, 's'); catch, end
end
