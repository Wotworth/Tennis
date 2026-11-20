function file = writeRecording(folder, cam, sc, truth, k)
%WRITERECORDING  Render camera k's footage and write it as a GoPro-like MP4.
%   Frames go to FFmpeg in chunks, the chunks are joined without re-encoding, and the sound and
%   metadata are added: creation_time (the camera's start, with sc.coarseError added, as a real
%   clock would be off), a timecode, and the camera serial in the comment tag (real files carry it
%   in the GPMF track; see tv.ingest). The file is named like a GoPro file: GX01<4 digits>.MP4.
%   Camera-like options (Chris, 22 Nov: Tuesday's dress rehearsal), all off by default:
%     sc.codec        'h264' (default) or 'hevc' (the Mission 1 Pro's codec)
%     sc.fileNumber   the 4-digit recording number (default 10 + k)
%     sc.chapterS     split into chapters of this many seconds: GX01nnnn, GX02nnnn, ... (GoPro's
%                     own split is at about 4 GB); default: one file
%     sc.lrv          also write the small proxy GL01nnnn.LRV beside each chapter (848 x 480, 30 fps)
%   The frame rate is the camera's own (cam.fps). Returns the first chapter's path.
if ~exist(folder, 'dir'), mkdir(folder); end
tmp = tempname();  mkdir(tmp);
cleanup = onCleanup(@() rmdirQuiet(tmp));
opt = struct('codec', 'h264', 'fileNumber', 10 + k, 'chapterS', Inf, 'lrv', false);
for f = fieldnames(opt)', if isfield(sc, f{1}), opt.(f{1}) = sc.(f{1}); end, end
[num, den] = rat(cam.fps, 1e-6);  rate = sprintf('%d/%d', num, den);
switch opt.codec
    case 'hevc', venc = sprintf('-c:v libx265 -preset ultrafast -crf %d -x265-params log-level=error -tag:v hvc1', sc.crf);
    otherwise,   venc = sprintf('-c:v libx264 -preset veryfast -crf %d', sc.crf);
end
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
    tv.util.run(sprintf(['%s -y -v error -f rawvideo -pix_fmt rgb24 -s %dx%d -r %s -i "%s" ' ...
        '%s -g 30 -pix_fmt yuv420p "%s"'], ff, cam.width, cam.height, rate, raw, venc, part));
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
whole = fullfile(tmp, 'whole.mp4');
tv.util.run(sprintf(['%s -y -v error -f concat -safe 0 -i "%s" -i "%s" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k ' ...
    '-metadata creation_time=%s -metadata comment="serial=%s" -timecode %s "%s"'], ...
    ff, list, wav, startUtc, cam.serial, tv.util.timecode(startUtc, cam.fps), whole));
% chapters: cut at whole frames, each chapter carrying its own start time and timecode
dur = nFrames / cam.fps;
nCh = max(1, ceil(dur / opt.chapterS - 1e-9));
for ch = 1:nCh
    t0 = (ch - 1) * opt.chapterS;  if ~isfinite(t0), t0 = 0; end
    name = fullfile(folder, sprintf('GX%02d%04d.MP4', ch, opt.fileNumber));
    if nCh == 1
        movefile(whole, name);
    else
        f0 = round(t0 * cam.fps);  f1 = min(nFrames, round(ch * opt.chapterS * cam.fps));
        st = tv.util.utcPlus(startUtc, f0 / cam.fps);
        % re-encoded at the cut so each chapter starts on a key frame exactly where the last ended
        tv.util.run(sprintf(['%s -y -v error -i "%s" -vf "select=between(n\\,%d\\,%d),setpts=PTS-STARTPTS" ' ...
            '-af "atrim=%.6f:%.6f,asetpts=PTS-STARTPTS" %s -pix_fmt yuv420p -r %s -c:a aac -b:a 128k ' ...
            '-metadata creation_time=%s -metadata comment="serial=%s" -timecode %s "%s"'], ...
            ff, whole, f0, f1 - 1, f0 / cam.fps, f1 / cam.fps, venc, rate, st, cam.serial, tv.util.timecode(st, cam.fps), name));
    end
    if opt.lrv
        tv.util.run(sprintf('%s -y -v error -i "%s" -vf scale=848:480 -r 30 -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 64k -f mp4 "%s"', ...
            ff, name, fullfile(folder, sprintf('GL%02d%04d.LRV', ch, opt.fileNumber))));
    end
    if ch == 1, file = name; end
end
end

function rmdirQuiet(d)
try, rmdir(d, 's'); catch, end
end
