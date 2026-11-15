function info = probe(file)
%PROBE  What ffprobe knows about a recording (TV-ING-10).
%   info.width, height, fps (nominal, e.g. 119.88), nFrames, pts (s, one per
%   frame, from the file; never assumed evenly spaced), startUtc (ISO, from
%   the timecode when present, which carries sub-second time, else the
%   creation time, whole seconds only), serial (from the comment tag of
%   synthetic files; real GoPro files: tv.ingest reads it from GPMF),
%   hasAudio, audioRate.
ffp = tv.util.ffmpeg('ffprobe');
q = @(args) strtrim(tv.util.run(sprintf('%s -v error %s "%s"', ffp, args, file)));
s = q('-select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames -of default=nw=1');
info.file   = file;
info.width  = str2double(field(s, 'width'));
info.height = str2double(field(s, 'height'));
r = sscanf(field(s, 'r_frame_rate'), '%d/%d');  info.fps = r(1) / r(2);
p = q('-select_streams v:0 -show_entries packet=pts_time -of csv=p=0');
info.pts = sort(sscanf(strrep(p, ',', ''), '%f'));
info.pts = info.pts - info.pts(1);
info.nFrames = numel(info.pts);
tags = q('-show_entries format_tags=creation_time,comment:stream_tags=timecode -of default=nw=1');
created = field(tags, 'TAG:creation_time');
tc = field(tags, 'TAG:timecode');
info.serial = '';
cm = field(tags, 'TAG:comment');
if strncmp(cm, 'serial=', 7), info.serial = cm(8:end); end
info.startUtc = created;  info.startSource = 'creation_time';
if ~isempty(tc) && ~isempty(created)
    % timecode HH:MM:SS:FF counts frames at round(fps); the date comes from creation_time
    v = sscanf(strrep(tc, ';', ':'), '%d:%d:%d:%d');
    d = sscanf(created, '%d-%d-%d');
    sec = v(3) + v(4) / round(info.fps);
    info.startUtc = sprintf('%04d-%02d-%02dT%02d:%02d:%06.3fZ', d(1), d(2), d(3), v(1), v(2), sec);
    info.startSource = 'timecode';
end
a = q('-select_streams a:0 -show_entries stream=sample_rate -of default=nw=1');
info.hasAudio = ~isempty(a);
info.audioRate = str2double(field(a, 'sample_rate'));
end

function v = field(txt, name)
v = '';
lines = strsplit(txt, sprintf('\n'));
for k = 1:numel(lines)
    if strncmp(lines{k}, [name '='], numel(name) + 1)
        v = strtrim(lines{k}(numel(name) + 2:end));
        return
    end
end
end
