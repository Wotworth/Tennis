function groups = chapters(names)
%CHAPTERS  Group GoPro chapter files into recordings (TV-ING-11).
%   GoPro splits a long recording into chapters: GXccnnnn.MP4 (and GH, GL
%   for LRV) where nnnn is the recording number and cc the chapter (01, 02,
%   ...); older cameras use GOPRnnnn.MP4 then GPccnnnn.MP4. Returns a
%   struct array: number (text), files (cell, in chapter order).
%   Nothing is re-encoded or joined: the pipeline reads the chapters as one
%   continuous timeline.
groups = struct('number', {}, 'files', {});
num = cell(size(names));  ch = zeros(size(names));
for k = 1:numel(names)
    [~, b] = fileparts(names{k});
    t = regexp(b, '^G[XHLP]?(\d{2})(\d{4})$', 'tokens', 'once');
    if ~isempty(t)
        ch(k) = str2double(t{1});  num{k} = t{2};
    else
        t = regexp(b, '^GOPR(\d{4})$', 'tokens', 'once');
        if isempty(t), num{k} = b; ch(k) = 0; else, num{k} = t{1}; ch(k) = 0; end
    end
end
u = unique(num);
for i = 1:numel(u)
    m = find(strcmp(num, u{i}));
    [~, o] = sort(ch(m));
    groups(end+1) = struct('number', u{i}, 'files', {names(m(o))}); %#ok<AGROW>
end
end
