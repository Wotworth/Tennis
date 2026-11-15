% Every RETUNE note in the code is listed in docs/VISION-RETUNE.md.
here = fileparts(mfilename('fullpath'));
doc = fileread(fullfile(here, '..', '..', 'docs', 'VISION-RETUNE.md'));

%% Every file with a RETUNE note appears in the list
files = [dir(fullfile(here, '..', '+tv', '**', '*.m')); dir(fullfile(here, '..', 'tools', '*.m'))];
missing = {};
for f = files(:)'
    txt = fileread(fullfile(f.folder, f.name));
    if isempty(strfind(txt, 'RETUNE(')), continue; end
    p = strrep(fullfile(f.folder, f.name), '\', '/');
    k = strfind(p, '+tv/');
    if isempty(k), k = strfind(p, 'tools/'); end
    rel = p(k(end):end);
    if isempty(strfind(doc, ['`' rel])), missing{end+1} = rel; end %#ok<AGROW>
end
assert(isempty(missing), 'Not in docs/VISION-RETUNE.md: %s', strjoin(missing, ', '))
