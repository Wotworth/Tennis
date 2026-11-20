function F = readFrames(info, first, count, scale)
%READFRAMES  Decode frames first..first+count-1 (0-based) as H-by-W-by-3-by-N uint8.
%   Uses FFmpeg with NVIDIA hardware decoding when a GPU is available, and
%   falls back to the CPU decoder otherwise or if that fails (TV-ARCH-02).
%   scale (optional, default 1) shrinks the frames, e.g. 0.25 for the
%   rally-finding pass.
if nargin < 4, scale = 1; end
count = min(count, info.nFrames - first);
if count <= 0, F = zeros(0, 0, 3, 0, 'uint8'); return; end
if isfield(info, 'chapters') && numel(info.chapters) > 1
    % a recording in chapters (tv.media.joinChapters): each frame is read from its own chapter file,
    % seeking there (seeking through the concat list returns nothing past the first chapter; 22 Nov)
    F = [];
    while count > 0
        c = find([info.chapters.first] <= first, 1, 'last');
        ch = info.chapters(c);  local = first - ch.first;
        n = min(count, ch.info.nFrames - local);
        part = tv.media.readFrames(ch.info, local, n, scale);
        if isempty(F), F = part; else, F = cat(4, F, part); end
        first = first + n;  count = count - n;
        if n <= 0, break; end
    end
    return
end
W = round(info.width * scale / 2) * 2;  H = round(info.height * scale / 2) * 2;
if scale == 1, W = info.width; H = info.height; end
t = info.pts(first + 1) - 0.25 / info.fps;          % accurate seek lands on this frame
raw = [tempname() '.rgb'];
vf = '';
if scale ~= 1, vf = sprintf('-vf scale=%d:%d:flags=area', W, H); end
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
