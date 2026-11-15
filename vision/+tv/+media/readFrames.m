function F = readFrames(info, first, count, scale)
%READFRAMES  Decode frames first..first+count-1 (0-based) as H-by-W-by-3-by-N uint8.
%   Uses FFmpeg with NVIDIA hardware decoding when a GPU is available, and
%   falls back to the CPU decoder otherwise or if that fails (TV-ARCH-02).
%   scale (optional, default 1) shrinks the frames, e.g. 0.25 for the
%   rally-finding pass.
if nargin < 4, scale = 1; end
count = min(count, info.nFrames - first);
if count <= 0, F = zeros(0, 0, 3, 0, 'uint8'); return; end
W = round(info.width * scale / 2) * 2;  H = round(info.height * scale / 2) * 2;
if scale == 1, W = info.width; H = info.height; end
t = info.pts(first + 1) - 0.25 / info.fps;          % accurate seek lands on this frame
raw = [tempname() '.rgb'];
vf = '';
if scale ~= 1, vf = sprintf('-vf scale=%d:%d:flags=area', W, H); end
base = sprintf('-ss %.6f -i "%s" -frames:v %d %s -f rawvideo -pix_fmt rgb24 "%s"', t, info.file, count, vf, raw);
ok = false;
if tv.util.useGpu()
    [st, ~] = system(sprintf('%s -y -v error -hwaccel cuda %s', tv.util.ffmpeg(), base));
    ok = st == 0;
end
if ~ok, tv.util.run(sprintf('%s -y -v error %s', tv.util.ffmpeg(), base)); end
fid = fopen(raw, 'r');  data = fread(fid, inf, 'uint8=>uint8');  fclose(fid);  delete(raw);
n = floor(numel(data) / (W * H * 3));
F = permute(reshape(data(1:n * W * H * 3), 3, W, H, n), [3 2 1 4]);
end
