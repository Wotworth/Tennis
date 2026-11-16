function archived = archiveStaged(stage, serial, cfg)
%ARCHIVESTAGED  Move one camera's checked files from staging to the archive (TV-ING-04).
%   For every file the manifest (stage/import.json) marks verified or wiped and that is still
%   in staging: copy to archive/<UTC date>/<serial>/, hashing as it goes, hash the archive copy
%   again, and only when both match the card's hash delete the staging copy and mark it
%   archived. The manifest is saved after every file, so a power cut loses at most the file
%   being copied (its archive copy keeps an .incomplete marker and is simply redone).
%   cfg.archiveFaultAfter (tests): simulate a power cut after that many files.
archived = {};
mfile = fullfile(stage, 'import.json');
if ~exist(mfile, 'file'), return; end
M = jsondecode(fileread(mfile));
if isempty(M.files), return; end
if ~isfield(M, 'keys'), M.keys = {}; end
M.keys = cellstr(M.keys);
done = 0;
for i = 1:numel(M.files)
    e = M.files(i);
    if ~any(strcmp(e.status, {'verified', 'wiped'})), continue; end
    src = fullfile(stage, e.name);
    if ~exist(src, 'file'), continue; end
    if isfield(cfg, 'archiveFaultAfter') && done >= cfg.archiveFaultAfter
        error('tv:ingest:power', 'Power lost during the archive move (simulated).');
    end
    day = archiveDay(src, stage, e.name);
    dst = fullfile(cfg.archive, day, serial, e.name);
    h = tv.ingest.copyHashed(src, dst, struct());
    if strcmp(h, e.hash) && strcmp(tv.ingest.sha256File(dst), e.hash)
        delete(src);
        M.files(i).status = 'archived';  M.files(i).archive = dst;
        archived{end+1} = dst; %#ok<AGROW>
    else
        cfg.notify('Archive error', sprintf('Archive copy of %s did not match; kept in staging.', e.name));
    end
    tv.util.writeJson(mfile, M);
    done = done + 1;
end
end

function day = archiveDay(file, stage, name)
% the UTC date of the recording; LRV and THM files follow their MP4
day = '';
[~, b] = fileparts(name);
mp4 = fullfile(stage, [regexprep(b, '^G[LH]', 'GX') '.MP4']);
if ~exist(mp4, 'file'), mp4 = file; end
try
    info = tv.media.probe(mp4);
    day = info.startUtc(1:10);
catch
end
if isempty(day), day = 'undated'; end
end
