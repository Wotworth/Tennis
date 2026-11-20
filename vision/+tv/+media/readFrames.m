function [F, how] = readFrames(info, first, count, scale)
%READFRAMES  Decode frames first..first+count-1 (0-based) as H-by-W-by-3-by-N uint8.
%   Uses FFmpeg with NVIDIA hardware decoding when a GPU is available, and
%   falls back to the CPU decoder otherwise or if that fails (TV-ARCH-02).
%   scale (optional, default 1) shrinks the frames, e.g. 0.25 for the
%   rally-finding pass. how says which way the frames came: 'pipe' (through memory) or 'file'.
if nargin < 4, scale = 1; end
count = min(count, info.nFrames - first);
how = 'file';
if count <= 0, F = zeros(0, 0, 3, 0, 'uint8'); return; end
if isfield(info, 'chapters') && numel(info.chapters) > 1
    % a recording in chapters (tv.media.joinChapters): each frame is read from its own chapter file,
    % seeking there (seeking through the concat list returns nothing past the first chapter; 22 Nov)
    F = [];
    while count > 0
        c = find([info.chapters.first] <= first, 1, 'last');
        ch = info.chapters(c);  local = first - ch.first;
        n = min(count, ch.info.nFrames - local);
        [part, how] = tv.media.readFrames(ch.info, local, n, scale);
        if isempty(F), F = part; else, F = cat(4, F, part); end
        first = first + n;  count = count - n;
        if n <= 0, break; end
    end
    return
end
W = round(info.width * scale / 2) * 2;  H = round(info.height * scale / 2) * 2;
if scale == 1, W = info.width; H = info.height; end
t = info.pts(first + 1) - 0.25 / info.fps;          % accurate seek lands on this frame
vf = '';
if scale ~= 1, vf = sprintf('-vf scale=%d:%d:flags=area', W, H); end
% frames through memory (Chris, 22 Nov, item 8): FFmpeg's output read straight from its pipe, one
% frame at a time, with no file written; the temporary file below is the fallback (identical frames,
% readFramesTest). TV_FRAMES_FILE=1 forces the file.
if isempty(getenv('TV_FRAMES_FILE')) && usejavaOk()
    try
        F = viaPipe(t, info, count, vf, W, H);
        if size(F, 4) == count || first + size(F, 4) >= info.nFrames, how = 'pipe'; return; end
    catch
    end
end
raw = [tempname() '.rgb'];
base = sprintf('-ss %.6f %s -frames:v %d %s -f rawvideo -pix_fmt rgb24 "%s"', t, tv.media.inputArgs(info.file), count, vf, raw);
ok = false;
if tv.util.useGpu()
    [st, ~] = tv.util.shell(sprintf('%s -y -v error -hwaccel cuda %s', tv.util.ffmpeg(), base));
    ok = st == 0;
end
if ~ok, tv.util.run(sprintf('%s -y -v error %s', tv.util.ffmpeg(), base)); end
fid = fopen(raw, 'r');  data = fread(fid, inf, 'uint8=>uint8');  fclose(fid);  delete(raw);
n = floor(numel(data) / (W * H * 3));
F = permute(reshape(data(1:n * W * H * 3), 3, W, H, n), [3 2 1 4]);
end

function F = viaPipe(t, info, count, vf, W, H)
args = {'-v', 'error'};
if tv.util.useGpu(), args = [args, {'-hwaccel', 'cuda'}]; end   % NVDEC; a failure falls back to the file path
args = [args, {'-ss', sprintf('%.6f', t)}, inputList(info.file), {'-frames:v', sprintf('%d', count)}];
if ~isempty(vf), v = strsplit(vf, ' '); args = [args, v]; end
args = [args, {'-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'}];
exe = strrep(tv.util.ffmpeg(), '"', '');
pb = javaObject('java.lang.ProcessBuilder', [{exe}, args]);
% FFmpeg's messages go to the null device (a File works in MATLAB and Octave alike; Redirect.DISCARD
% is a static field neither reaches the same way)
if ispc, nul = 'NUL'; else, nul = '/dev/null'; end
pb.redirectError(javaObject('java.io.File', nul));
pr = pb.start();
ch = javaMethod('newChannel', 'java.nio.channels.Channels', pr.getInputStream());
n = W * H * 3;  F = zeros(H, W, 3, count, 'uint8');  got = 0;
try
    for k = 1:count
        bb = javaMethod('allocate', 'java.nio.ByteBuffer', n);
        while bb.hasRemaining()
            if ch.read(bb) < 0, break; end
        end
        if bb.position() < n, break; end
        d = typecast(int8(bb.array()), 'uint8');
        F(:, :, :, k) = permute(reshape(d, 3, W, H), [3 2 1]);
        got = k;
    end
catch err
    pr.destroy();  rethrow(err);
end
ch.close();  pr.waitFor();
F = F(:, :, :, 1:got);
end

function a = inputList(file)
% FFmpeg's input as separate arguments (a chapter list needs the concat demuxer)
if numel(file) > 9 && strcmpi(file(end - 8:end), '.ffconcat')
    a = {'-f', 'concat', '-safe', '0', '-i', file};
else
    a = {'-i', file};
end
end

function ok = usejavaOk()
persistent v
if isempty(v)
    v = false;
    try, javaObject('java.lang.ProcessBuilder', {'x'}); v = true; catch, end
end
ok = v;
end
