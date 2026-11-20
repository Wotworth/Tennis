function file = joinChapters(files, folder)
%JOINCHAPTERS  One recording's chapters as one input: the file itself, or a chapter list.
%   file = tv.media.joinChapters({'GX010042.MP4', 'GX020042.MP4'})  -> '.../GX0042.ffconcat'
%   A single chapter is returned as it is. Several (in chapter order, tv.ingest.chapters) are listed
%   in a .ffconcat file beside them (or in folder), which tv.media.probe, readFrames and readAudio
%   read as one continuous recording. 22 Nov (dress rehearsal): the PC passed only the first chapter
%   of each recording to the pipeline, so a session longer than one chapter (about 4 GB: a minute or
%   two at 4K240) was cut short without a warning.
if ischar(files), files = {files}; end
if numel(files) == 1, file = files{1}; return; end
[d, b] = fileparts(files{1});
if nargin < 2 || isempty(folder), folder = d; end
num = regexp(b, '^G[XHLP]\\d{2}(\\d{4})$', 'tokens', 'once');
if isempty(num), num = {b}; end
file = fullfile(folder, sprintf('GX%s.ffconcat', num{1}));
fid = fopen(file, 'w');
if fid < 0, file = fullfile(tempdir(), sprintf('GX%s_%d.ffconcat', num{1}, round(1e6 * rand()))); fid = fopen(file, 'w'); end
fprintf(fid, 'ffconcat version 1.0\n');
for k = 1:numel(files)
    p = files{k};
    if ~isAbs(p), p = fullfile(pwd, p); end
    fprintf(fid, 'file ''%s''\n', strrep(p, '''', '''\'''''));
end
fclose(fid);
end

function t = isAbs(p)
t = ~isempty(p) && (p(1) == '/' || p(1) == '\' || (numel(p) > 1 && p(2) == ':'));
end
