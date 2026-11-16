function archived = resumeArchive(cfg)
%RESUMEARCHIVE  Finish archive moves a power cut or crash interrupted (TV-ING-04, TV-OPS-02).
%   Every staging/<serial>/import.json with files still marked verified or wiped and present
%   in staging is handed to tv.ingest.archiveStaged. The watcher calls this on every pass, so
%   the files reach the archive even though their card was already wiped. Cheap when there
%   is nothing to do.
archived = {};
if ~exist(cfg.staging, 'dir'), return; end
D = dir(cfg.staging);
for d = D([D.isdir] & ~strncmp({D.name}, '.', 1))'
    stage = fullfile(cfg.staging, d.name);
    mfile = fullfile(stage, 'import.json');
    if ~exist(mfile, 'file'), continue; end
    M = jsondecode(fileread(mfile));
    if isempty(M.files), continue; end
    pending = any(arrayfun(@(e) any(strcmp(e.status, {'verified', 'wiped'})) && exist(fullfile(stage, e.name), 'file'), M.files));
    if pending
        a = tv.ingest.archiveStaged(stage, d.name, cfg);
        archived = [archived, a]; %#ok<AGROW>
        if ~isempty(a), cfg.notify('Archive resumed', sprintf('Camera %s: %d files moved to the archive after an interruption.', d.name, numel(a))); end
    end
end
end
