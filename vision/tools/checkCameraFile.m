function R = checkCameraFile(file, outFile)
%CHECKCAMERAFILE  Is the first real Mission 1 Pro file what the PC expects? (Chris, 20 Nov; TV-ING)
%   R = checkCameraFile('GX010042.MP4')            prints the checks
%   R = checkCameraFile(file, 'camera-file.md')    also writes them as a report
%   Run on the first file from each camera before anything else. Everything the ingest and the
%   pipeline assume about a GoPro file is checked against the file itself:
%     1. the name (GX/GH + chapter + number) and the chapter grouping (tv.ingest.chapters);
%     2. the low-resolution copy (LRV) beside it on the card, if the folder is there;
%     3. the picture: codec, bit depth, 3840 x 2160, the frame rate, every frame's own time and
%        how evenly they come (dropped or doubled frames);
%     4. the start time: the timecode track (sub-second) or only the creation time;
%     5. the telemetry (GPMF): present, the camera's serial and model, GPS fix, gyro, and the
%        shutter, ISO and white balance the camera really used;
%     6. the sound track (for the rally finder and the reel);
%     7. that tv.media.probe and tv.gpmf.summary read it without error.
%   R.checks: one row per check {name, 'ok' | 'warn' | 'FAIL', what was found}.
if nargin < 2, outFile = ''; end
R.file = file;  R.checks = cell(0, 3);
add = @(name, st, txt) addRow(name, st, txt);
[folder, base, ext] = fileparts(file);
% 1. name and chapters
tok = regexp([base ext], '^G([XH])(\d\d)(\d{4})\.MP4$', 'tokens', 'once', 'ignorecase');
if isempty(tok), add('name', 'warn', sprintf('%s is not GX/GH + chapter + number: the chapter grouping may not join it', [base ext]));
else
    g = tv.ingest.chapters({[base ext]});
    add('name', 'ok', sprintf('%s: recording %s, chapter %s (grouped as %s)', [base ext], tok{3}, tok{2}, g(1).number));
end
% 2. the LRV beside it
if ~isempty(folder) && exist(folder, 'dir')
    lrv = dir(fullfile(folder, ['GL' base(3:end) '.LRV']));
    if isempty(lrv), lrv = dir(fullfile(folder, [base '.LRV'])); end
    if isempty(lrv), add('low-resolution copy', 'warn', 'no LRV file beside it');
    else
        L = tv.media.probe(fullfile(folder, lrv(1).name));
        add('low-resolution copy', 'ok', sprintf('%s: %d x %d at %.2f frames a second', lrv(1).name, L.width, L.height, L.fps));
    end
end
% 3. the picture
ffp = tv.util.ffmpeg('ffprobe');
q = @(args) strtrim(tv.util.run(sprintf('%s -v error %s "%s"', ffp, args, file)));
v = q('-select_streams v:0 -show_entries stream=codec_name,profile,pix_fmt,width,height,r_frame_rate,avg_frame_rate,bit_rate -of default=nw=1');
add('video', 'ok', strrep(v, sprintf('\n'), ', '));
P = [];
try
    P = tv.media.probe(file);
    st = 'ok';  if P.width ~= 3840 || P.height ~= 2160, st = 'warn'; end
    add('picture size', st, sprintf('%d x %d (expected 3840 x 2160)', P.width, P.height));
    dt = diff(P.pts);  nominal = 1 / P.fps;
    odd = nnz(abs(dt - nominal) > 0.25 * nominal);
    st = 'ok';  if abs(P.fps - 240000 / 1001) > 0.1 && abs(P.fps - 240) > 0.1, st = 'warn'; end
    add('frame rate', st, sprintf('%.3f frames a second nominal; %d frames; median gap %.4f ms; %d gaps more than a quarter-frame off (dropped or doubled frames)', ...
        P.fps, P.nFrames, 1000 * median(dt), odd));
    st = 'ok';  if ~strcmp(P.startSource, 'timecode'), st = 'warn'; end
    add('start time', st, sprintf('%s from the %s', P.startUtc, P.startSource));
    st = 'ok';  if ~P.hasAudio, st = 'warn'; end
    add('sound', st, sprintf('audio %d, %d Hz', P.hasAudio, P.audioRate));
catch err
    add('tv.media.probe', 'FAIL', err.message);
end
bits = 8;  if ~isempty(strfind(v, '10le')) || ~isempty(strfind(v, 'p010')), bits = 10; end
add('bit depth', 'ok', sprintf('%d-bit (the detector reads 8-bit RGB through FFmpeg either way)', bits));
% 4./5. telemetry
streams = q('-show_entries stream=index,codec_type,codec_tag_string -of csv=p=0');
add('streams', 'ok', strrep(streams, sprintf('\n'), '; '));
if isempty(strfind(streams, 'gpmd')), add('telemetry', 'FAIL', 'no gpmd stream: no serial, GPS or gyro from the file');
else
    try
        S = tv.gpmf.summary(file);
        fix = S.payloads(:, 3);
        add('telemetry', 'ok', sprintf('serial %s, model %s; %d samples; GPS 3D fix in %d', S.serial, S.model, size(S.payloads, 1), nnz(fix == 3)));
        if isfield(S, 'settings') && ~isempty(S.settings)
            se = zeros(1, 3);                                       % [shutter ISO white balance], median over the file
            for c = 1:3, x = S.settings(:, c);  x = x(isfinite(x));  se(c) = NaN;  if ~isempty(x), se(c) = median(x); end, end
            st = 'ok';  if se(1) > 1 / 1500, st = 'warn'; end      % slower than about 1/1920: a smeared ball
            add('exposure', st, sprintf('shutter 1/%.0f s, ISO %.0f, white balance %.0f K (median over the file)', 1 / se(1), se(2), se(3)));
        end
        st = 'ok';  if ~isfinite(S.utcOffset), st = 'warn'; end
        add('GPS time', st, sprintf('file time to UTC offset %.3f s', S.utcOffset));
    catch err
        add('tv.gpmf.summary', 'FAIL', err.message);
    end
end
if ~isempty(strfind(streams, 'tmcd')), add('timecode track', 'ok', 'present');
else, add('timecode track', 'warn', 'none: the start time is the creation time (whole seconds); the ball finds the exact timing'); end
% report
L = {sprintf('# Camera file check: %s', [base ext]), '', '| Check | Result | Found |', '|---|---|---|'};
for i = 1:size(R.checks, 1), L{end+1} = sprintf('| %s | %s | %s |', R.checks{i, :}); end %#ok<AGROW>
R.text = strjoin(L, newline);
fprintf('%s\n', R.text);
if ~isempty(outFile), fid = fopen(outFile, 'w');  fprintf(fid, '%s\n', R.text);  fclose(fid); end

    function addRow(name, st, txt)
        R.checks(end+1, :) = {name, st, txt};
    end
end
