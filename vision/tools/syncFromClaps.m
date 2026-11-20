function R = syncFromClaps(file1, file2, opts)
%SYNCFROMCLAPS  How far apart the two cameras' clocks are, and how fast they drift (home test c, 21 Nov).
%   R = syncFromClaps('CAM1/GX010001.MP4', 'CAM2/GX010001.MP4')   (the LRV files work too)
%   Chris claps where both cameras hear it at the start and every 10 minutes (manual 17.4). Each clap
%   is found in camera 1's sound and matched in camera 2's (tv.sync.clapOffsets). Printed per clap:
%   camera 1's file time, camera 2's, and the offset between them; then
%     - the timecode's own error: where the timecode put camera 2's start against where the claps put
%       it (TV-SYNC-01: what the session's first sync step starts from);
%     - the drift: the change of offset per second of recording, in parts per million (TV-SYNC-03's
%       prior, 0 +/- 100 ppm, is checked against it);
%     - the scatter of the claps about that straight line (how well a clap times the cameras).
%   Only the sound is read, at 16 kHz.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'fs'), opts.fs = 16000; end
i1 = tv.media.probe(file1);  i2 = tv.media.probe(file2);
dt0 = 0;  src = 'none';
if isfield(i1, 'startUtc') && isfield(i2, 'startUtc') && ~isempty(i1.startUtc) && ~isempty(i2.startUtc)
    dt0 = secs(i2.startUtc) - secs(i1.startUtc);  src = sprintf('%s / %s', i1.startSource, i2.startSource);
end
y1 = audioAt(file1, opts.fs);  y2 = audioAt(file2, opts.fs);
C = tv.sync.clapOffsets(y1, y2, opts.fs, dt0, opts);
R.claps = C;  R.timecodeOffset = dt0;  R.startSource = src;
fprintf('%s and %s: %d claps matched (camera 2''s file starts %.3f s after camera 1''s by %s)\n', file1, file2, size(C, 1), dt0, src);
fprintf('  camera 1 time   camera 2 time   offset (ms)   match\n');
for k = 1:size(C, 1), fprintf('  %12.3f    %12.3f    %10.3f    %.2f\n', C(k, 1), C(k, 2), 1000 * C(k, 3), C(k, 4)); end
if size(C, 1) >= 1
    R.timecodeErrorMs = 1000 * (C(1, 3) - dt0);
    fprintf('timecode error at the first clap: %.2f ms (the claps against the timecode)\n', R.timecodeErrorMs);
end
if size(C, 1) >= 2
    p = polyfit(C(:, 1), C(:, 3), 1);
    R.driftPpm = 1e6 * p(1);  R.scatterMs = 1000 * std(C(:, 3) - polyval(p, C(:, 1)));
    fprintf('drift: the offset grows %.1f ms an hour (%.1f ppm; positive: camera 2''s clock runs slow); claps scatter %.3f ms about the line\n', ...
        3.6 * R.driftPpm, R.driftPpm, R.scatterMs);
end
end

function y = audioAt(file, fs)
wav = [tempname() '.wav'];
tv.util.run(sprintf('%s -y -v error -i "%s" -vn -ac 1 -ar %d -c:a pcm_s16le "%s"', tv.util.ffmpeg(), file, fs, wav));
y = audioread(wav);  delete(wav);
end

function s = secs(iso)
% seconds of the day (enough: both cameras start within minutes of each other)
v = sscanf(iso(12:end), '%d:%d:%f');
s = v(1) * 3600 + v(2) * 60 + v(3);
end
