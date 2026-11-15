function F = cardFiles(cardRoot)
%CARDFILES  The GoPro files on a card: MP4, LRV and THM under DCIM/*GOPRO*.
%   Returns a struct array: name, folder, path, bytes, date.
F = struct('name', {}, 'folder', {}, 'path', {}, 'bytes', {}, 'date', {});
dcim = fullfile(cardRoot, 'DCIM');
if ~exist(dcim, 'dir'), return; end
dd = dir(dcim);
for d = dd(:)'
    if ~d.isdir || isempty(regexpi(d.name, 'GOPRO', 'once')), continue; end
    ff = dir(fullfile(dcim, d.name));
    for f = ff(:)'
        [~, ~, ext] = fileparts(f.name);
        if f.isdir || ~any(strcmpi(ext, {'.MP4', '.LRV', '.THM'})), continue; end
        F(end+1) = struct('name', f.name, 'folder', d.name, 'path', fullfile(dcim, d.name, f.name), ... %#ok<AGROW>
            'bytes', f.bytes, 'date', f.date);
    end
end
end
