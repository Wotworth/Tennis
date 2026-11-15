function [payloads, times] = extract(file)
%EXTRACT  The GPMF telemetry track of a GoPro MP4, one payload per sample (TV-ING-12).
%   FFmpeg copies the 'gpmd' data stream out unchanged; ffprobe gives each
%   sample's time and size, which splits the bytes into payloads (about one
%   second each). times(k, :) = [start duration] in file seconds.
ffp = tv.util.ffmpeg('ffprobe');
s = tv.util.run(sprintf('%s -v error -show_entries stream=index,codec_tag_string -of csv=p=0 "%s"', ffp, file));
lines = strsplit(strtrim(s), sprintf('\n'));
idx = -1;
for k = 1:numel(lines)
    p = strsplit(lines{k}, ',');
    if numel(p) >= 2 && strcmp(strtrim(p{2}), 'gpmd'), idx = str2double(p{1}); end
end
payloads = {};  times = zeros(0, 2);
if idx < 0, return; end
pk = tv.util.run(sprintf('%s -v error -select_streams %d -show_entries packet=pts_time,duration_time,size -of csv=p=0 "%s"', ffp, idx, file));
v = sscanf(strrep(strtrim(pk), ',', ' '), '%f');
v = reshape(v, 3, [])';                                 % pts, duration, size
raw = [tempname() '.bin'];
tv.util.run(sprintf('%s -y -v error -i "%s" -map 0:%d -c copy -f data "%s"', tv.util.ffmpeg(), file, idx, raw));
fid = fopen(raw, 'r');  b = fread(fid, inf, 'uint8=>uint8')';  fclose(fid);  delete(raw);
o = 0;
for k = 1:size(v, 1)
    n = v(k, 3);
    if o + n > numel(b), break; end
    payloads{end+1} = b(o + 1:o + n); %#ok<AGROW>
    times(end+1, :) = v(k, 1:2); %#ok<AGROW>
    o = o + n;
end
end
