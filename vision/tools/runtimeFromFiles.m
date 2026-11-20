function R = runtimeFromFiles(folder, opts)
%RUNTIMEFROMFILES  How long a camera really recorded, from its files (Chris's home test d, 21 Nov).
%   R = runtimeFromFiles('HOME/CAM1')     a folder holding one camera's files of the long recording
%   R = runtimeFromFiles('HOME/CAM1', struct('sizes', T))   T: a table of name and bytes when only the
%       LRV files were uploaded and Chris sent the big files' sizes (manual 17.4)
%   Groups the files into recordings and chapters (tv.ingest.chapters), then per recording: chapters,
%   the total time recorded (each chapter's own duration, from its frame times), gaps between
%   chapters (a dropped piece shows as a gap between one chapter's end and the next one's start),
%   the card used per minute (from the big files' sizes), and how long a card of 128, 256 and
%   512 GB lasts at that rate. With Chris's notes on what stopped each camera (heat, cold, battery,
%   card), this is the runtime Tuesday's clip plan (manual 16.6) is built from.
if nargin < 2, opts = struct(); end
f = [dir(fullfile(folder, '*.MP4')); dir(fullfile(folder, '*.mp4'))];
if isempty(f), f = dir(fullfile(folder, '*.LRV')); end   % only the small files uploaded: time from them
if isempty(f), error('tv:runtime:none', 'No MP4 or LRV files in %s.', folder); end
names = {f.name};
G = tv.ingest.chapters(names);
R = struct('recording', {}, 'chapters', {}, 'minutes', {}, 'gapsS', {}, 'gbPerMinute', {});
for g = G(:)'
    secs = 0;  gaps = [];  bytes = 0;  lastEnd = NaN;
    for c = 1:numel(g.files)
        file = fullfile(folder, g.files{c});
        info = tv.media.probe(file);
        d = info.pts(end) - info.pts(1) + median(diff(info.pts));
        secs = secs + d;
        st = startSeconds(info);
        if isfinite(lastEnd) && isfinite(st), gaps(end+1) = st - lastEnd; end %#ok<AGROW>
        lastEnd = st + d;
        b = fileBytes(folder, g.files{c}, opts);
        bytes = bytes + b;
    end
    r.recording = g.number;  r.chapters = numel(g.files);  r.minutes = secs / 60;  r.gapsS = gaps;
    r.gbPerMinute = bytes / 1e9 / max(r.minutes, eps);
    R(end+1) = r; %#ok<AGROW>
    fprintf('recording %s: %d chapters, %.1f min recorded', r.recording, r.chapters, r.minutes);
    if ~isempty(gaps), fprintf(', gaps between chapters %s s', mat2str(round(gaps, 2))); end
    if bytes > 0
        fprintf(', %.2f GB a minute: a 128 / 256 / 512 GB card lasts %.0f / %.0f / %.0f min', r.gbPerMinute, ...
            128 / r.gbPerMinute, 256 / r.gbPerMinute, 512 / r.gbPerMinute);
    end
    fprintf('\n');
end
end

function s = startSeconds(info)
s = NaN;
if isfield(info, 'startUtc') && numel(info.startUtc) >= 19
    v = sscanf(info.startUtc(12:end), '%d:%d:%f');
    if numel(v) == 3, s = v(1) * 3600 + v(2) * 60 + v(3); end
end
end

function b = fileBytes(folder, name, opts)
% the big file's size: from the folder, or from Chris's list when only the LRV is here
[~, base, ext] = fileparts(name);
b = 0;
if strcmpi(ext, '.LRV')
    big = ['GX' base(3:end) '.MP4'];
    if isfield(opts, 'sizes')
        T = opts.sizes;  k = find(strcmpi(T.name, big), 1);
        if ~isempty(k), b = T.bytes(k); end
    end
else
    d = dir(fullfile(folder, name));  b = d.bytes;
end
end
