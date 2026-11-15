function freed = retention(cfg)
%RETENTION  Make room on the archive drive (TV-OPS-03).
%   Raw footage older than cfg.retentionDays.raw days is deleted, but only
%   for sessions already processed (their session.json exists), and never
%   the TV-PH-0 trial footage (files under a folder named 'trials').
%   Unprocessed raw footage is never deleted. Returns bytes freed.
%   RETUNE(real use): the spec also keeps full-resolution rally segments
%   for 3 months; those are not cut out yet, so raw footage is the only
%   thing cleaned.
freed = 0;
if ~isfield(cfg, 'retentionDays'), return; end
days = dir(cfg.archive);
nowDays = datenum(tv.util.nowUtc(), 'yyyy-mm-ddTHH:MM:SS');
for d = days(:)'
    if ~d.isdir || d.name(1) == '.' || strcmp(d.name, 'trials'), continue; end
    try, day = datenum(d.name, 'yyyy-mm-dd'); catch, continue; end
    if nowDays - day <= cfg.retentionDays.raw, continue; end
    processed = ~isempty(dir(fullfile(cfg.sessions, [d.name 'T*'], 'session.json')));
    if ~processed, continue; end
    files = dir(fullfile(cfg.archive, d.name, '**', '*.*'));
    for f = files(:)'
        if f.isdir, continue; end
        freed = freed + f.bytes;
        delete(fullfile(f.folder, f.name));
    end
end
end
