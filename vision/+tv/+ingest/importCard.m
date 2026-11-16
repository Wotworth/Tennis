function rep = importCard(cardRoot, cfg)
%IMPORTCARD  Copy, verify and wipe one camera's card (TV-ING-02 to TV-ING-09).
%   1. Lists the GoPro files and identifies the camera by the serial number
%      inside its MP4s, never by drive letter (TV-ING-02). An unknown serial
%      is imported as a new camera, with an alert.
%   2. Checks free space; below the limit it runs the retention clean-up
%      first and refuses (with an alert) only if that is not enough (TV-ING-09).
%   3. Copies every file to staging, hashing as it reads, then hashes the
%      staging copy and compares (TV-ING-04, 05). Progress and state are kept
%      in a manifest, so a pulled card resumes where it stopped (TV-ING-07).
%   4. Only when every file is verified: deletes those files from the card
%      (never folders), ejects it and reports it safe to remove (TV-ING-06).
%   5. Moves each file to archive/<UTC date>/<serial>/, hashing the archive
%      copy before deleting the staging copy (TV-ING-04).
%   cfg fields: staging, archive, cameras (struct array serial, role),
%   wipeCardAfterImport, minFreeFraction, notify (@(title, text)),
%   light (@(state)), freeSpace (@(folder) bytes free and total),
%   retention (@() run the clean-up), copyOpts (tests).
%   Slow port check (Chris, 16 Nov): once cfg.slowCheckBytes (256 MB) are
%   copied, a reader averaging under cfg.slowReaderMBps (45 MB/s) is almost
%   certainly on a USB 2.0 port (about 35-40 MB/s at best; a UHS-I card on a
%   5 Gbps port gives about 90): one alert, and the import carries on.
%   cfg.now (@() seconds) is the clock, replaceable in tests.
%   rep.status: 'done', 'interrupted' or 'refused'.
F = tv.ingest.cardFiles(cardRoot);
rep = struct('status', 'done', 'serial', '', 'role', '', 'files', 0, 'bytes', 0, 'archived', {{}});
if isempty(F), rep.status = 'empty'; return; end
mp4 = F(strcmpi(cellfun(@(n) n(end-2:end), {F.name}, 'UniformOutput', false), 'MP4'));
serial = '';
for f = mp4(:)'
    serial = cameraSerial(f.path);
    if ~isempty(serial), break; end
end
if isempty(serial), serial = 'UNKNOWN'; end
role = '';
if isfield(cfg, 'cameras') && ~isempty(cfg.cameras)
    k = find(strcmp({cfg.cameras.serial}, serial), 1);
    if ~isempty(k), role = cfg.cameras(k).role; end
end
if isempty(role)
    role = ['new-' serial];
    cfg.notify('New camera', sprintf('Camera %s is not in the config; imported as a new camera.', serial));
end
rep.serial = serial;  rep.role = role;  rep.files = numel(F);  rep.bytes = sum([F.bytes]);
% free space (TV-ING-09)
need = rep.bytes;
[free, total] = cfg.freeSpace(cfg.staging);
if (free - need) / total < cfg.minFreeFraction
    cfg.retention();
    [free, total] = cfg.freeSpace(cfg.staging);
    if (free - need) / total < cfg.minFreeFraction
        cfg.notify('Import refused', sprintf('Not enough free space for %.1f GB from camera %s.', need / 1e9, serial));
        cfg.light('error');
        rep.status = 'refused';
        return
    end
end
stage = fullfile(cfg.staging, serial);
if ~exist(stage, 'dir'), mkdir(stage); end
mfile = fullfile(stage, 'import.json');
M = loadManifest(mfile);
cfg.notify('Import started', sprintf('Camera %s (%s): %d files, %.1f GB.', serial, role, numel(F), need / 1e9));
cfg.light('copying');
% --- copy and verify ---------------------------------------------------------------
if ~isfield(cfg, 'slowReaderMBps'), cfg.slowReaderMBps = 45; end
if ~isfield(cfg, 'slowCheckBytes'), cfg.slowCheckBytes = 256 * 2^20; end
if ~isfield(cfg, 'now'), t00 = tic; cfg.now = @() toc(t00); end
tCopy = cfg.now();  copied = 0;  warned = false;  rep.mbps = NaN;
for f = F(:)'
    key = sprintf('%s|%d|%s', f.name, f.bytes, f.date);
    e = entry(M, key);
    if ~isempty(e) && any(strcmp(e.status, {'verified', 'wiped', 'archived'})), continue; end
    dst = fullfile(stage, f.name);
    try
        h = tv.ingest.copyHashed(f.path, dst, cfg.copyOpts);
    catch err
        M = setEntry(M, key, struct('name', f.name, 'bytes', f.bytes, 'hash', '', 'status', 'incomplete', 'archive', ''));
        tv.util.writeJson(mfile, M);
        cfg.notify('Import interrupted', sprintf('Camera %s: %s Put the card back to resume.', serial, err.message));
        cfg.light('error');
        rep.status = 'interrupted';
        return
    end
    copied = copied + f.bytes;
    rep.mbps = copied / 1e6 / max(cfg.now() - tCopy, eps);
    if ~warned && copied >= cfg.slowCheckBytes && rep.mbps < cfg.slowReaderMBps
        warned = true;
        cfg.notify('Slow card reader', sprintf(['Camera %s copies at %.0f MB/s: its reader is probably on a slow USB 2.0 port ', ...
            '(the four on the back marked without SS). Move it to a 5 Gbps port next time; this import carries on.'], serial, rep.mbps));
    end
    h2 = tv.ingest.sha256File(dst);
    st = 'verified';
    if ~strcmp(h, h2), st = 'mismatch'; end
    M = setEntry(M, key, struct('name', f.name, 'bytes', f.bytes, 'hash', h, 'status', st, 'archive', ''));
    tv.util.writeJson(mfile, M);
end
if any(strcmp({M.files.status}, 'mismatch'))
    cfg.notify('Import error', sprintf('Camera %s: a copy did not match the card. The card was not wiped.', serial));
    cfg.light('error');
    rep.status = 'interrupted';
    return
end
% --- wipe the card: only verified files, never folders (TV-ING-06) ------------------------
if cfg.wipeCardAfterImport
    for f = F(:)'
        key = sprintf('%s|%d|%s', f.name, f.bytes, f.date);
        e = entry(M, key);
        if ~isempty(e) && strcmp(e.status, 'verified')
            delete(f.path);
            M = setEntry(M, key, setfield(e, 'status', 'wiped')); %#ok<SFLD>
        end
    end
    tv.util.writeJson(mfile, M);
    tv.ingest.eject(cardRoot);
end
cfg.light('safe');
cfg.notify('Cards safe to remove', sprintf('Camera %s: %d files copied and checked.', serial, numel(F)));
% --- move to the archive, verifying the archive copy -------------------------------------------
for i = 1:numel(M.files)
    e = M.files(i);
    if ~any(strcmp(e.status, {'verified', 'wiped'})), continue; end
    src = fullfile(stage, e.name);
    if ~exist(src, 'file'), continue; end
    day = archiveDay(src, stage, e.name);
    dst = fullfile(cfg.archive, day, serial, e.name);
    h = tv.ingest.copyHashed(src, dst, struct());
    if strcmp(h, e.hash) && strcmp(tv.ingest.sha256File(dst), e.hash)
        delete(src);
        M.files(i).status = 'archived';  M.files(i).archive = dst;
        rep.archived{end+1} = dst;
    else
        cfg.notify('Archive error', sprintf('Archive copy of %s did not match; kept in staging.', e.name));
    end
    tv.util.writeJson(mfile, M);
end
end

% ============================================================================================
function serial = cameraSerial(file)
serial = '';
try
    S = tv.gpmf.summary(file);  serial = S.serial;
catch
end
if isempty(serial)
    try, info = tv.media.probe(file); serial = info.serial; catch, end
end
end

function M = loadManifest(f)
if exist(f, 'file')
    M = jsondecode(fileread(f));
    if isempty(M.files), M.files = emptyFiles(); end
    if ~isfield(M, 'keys'), M.keys = {}; end
    M.keys = cellstr(M.keys);
else
    M = struct('keys', {{}}, 'files', emptyFiles());
end
end

function f = emptyFiles()
f = struct('name', {}, 'bytes', {}, 'hash', {}, 'status', {}, 'archive', {});
end

function e = entry(M, key)
e = [];
i = find(strcmp(M.keys, key), 1);
if ~isempty(i), e = M.files(i); end
end

function M = setEntry(M, key, e)
i = find(strcmp(M.keys, key), 1);
if isempty(i), M.keys{end+1} = key; M.files(end+1) = e; else, M.files(i) = e; end
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
