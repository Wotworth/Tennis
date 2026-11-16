% Card import, telemetry and session pairing (TV-ING-01 to TV-ING-22, AC-01, AC-02).
fx = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'gopro', 'hero8.mp4');
root = tempname();  mkdir(root);

%% GoPro telemetry: serial, model, one payload a second, camera settings (TV-ING-12)
S = tv.gpmf.summary(fx);
assert(strcmp(S.serial, 'C3331324501403'))
assert(strcmp(S.model, 'HERO8 Black'))
assert(size(S.payloads, 1) == 13 && abs(S.payloads(2, 1) - 1.001) < 0.01)
assert(abs(S.settings(1, 1) - 1/861) < 2e-4)          % shutter time
assert(isnan(S.utcOffset) && strcmp(S.utcSource, 'camera clock'))   % no GPS fix in the sample

%% GPMF values: scaled GPS and signed gyro rates
S = tv.gpmf.summary(fx);
assert(all(abs(S.payloads(2:end, 4)) <= 90) && all(S.payloads(:, 7) > 0))

%% Chapter files group into recordings, in chapter order (TV-ING-11)
g = tv.ingest.chapters({'GX020007.MP4', 'GX010007.MP4', 'GX010008.MP4'});
assert(numel(g) == 2 && strcmp(g(1).files{1}, 'GX010007.MP4') && strcmp(g(1).files{2}, 'GX020007.MP4'))

%% A card is copied, checked, wiped (files only) and archived; hashes match (AC-01, AC-02)
card = fullfile(root, 'cardA');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T15:00:00.000Z', [11 12]);
before = tv.ingest.cardFiles(card);
hashes = cellfun(@tv.ingest.sha256File, {before.path}, 'UniformOutput', false);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcA'));
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.status, 'done') && strcmp(rep.role, 'cam1') && numel(rep.archived) == 6)
assert(isempty(tv.ingest.cardFiles(card)) && exist(fullfile(card, 'DCIM', '100GOPRO'), 'dir') == 7)
for k = 1:numel(before)
    a = rep.archived{strcmp(cellfun(@(p) p(end-numel(before(k).name)+1:end), rep.archived, 'UniformOutput', false), before(k).name)};
    assert(strcmp(tv.ingest.sha256File(a), hashes{k}))
end
L = tv.testing.readLines(lg.notify);
assert(strncmp(L{1}, 'Import started', 14) && any(strncmp(L, 'Cards safe to remove', 20)))
assert(isempty(dir(fullfile(cfg.staging, 'C3501325000001', '*.MP4'))))   % staging emptied after the archive check
assert(exist(fullfile(cfg.archive, '2026-11-14', 'C3501325000001', 'GX010011.MP4'), 'file') == 2)   % by UTC date and serial

%% A card pulled mid-copy is not wiped, and resumes when it comes back (TV-ING-07)
card = fullfile(root, 'cardB');
tv.testing.fakeCard(card, 'C3501325000002', '2026-11-14T15:00:00.500Z', [21 22]);
n0 = numel(tv.ingest.cardFiles(card));
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcB'), struct('faultAfterBytes', 20000));
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.status, 'interrupted') && numel(tv.ingest.cardFiles(card)) == n0)
assert(~isempty(dir(fullfile(cfg.staging, 'C3501325000002', '*.incomplete'))))
cfg.copyOpts = struct();                               % the card is back
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.status, 'done') && isempty(tv.ingest.cardFiles(card)))

%% A reader on a slow USB 2.0 port is reported once, and the import carries on (Chris, 16 Nov)
card = fullfile(root, 'cardS');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T17:00:00.000Z', [41 42]);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcS'));
clk = javaObject('java.util.concurrent.atomic.AtomicLong', 0);
cfg.now = @() double(clk.addAndGet(100));        % 100 s per tick: far too slow
cfg.slowCheckBytes = 1;
rep = tv.ingest.importCard(card, cfg);
L = tv.testing.readLines(lg.notify);
assert(strcmp(rep.status, 'done') && nnz(strncmp(L, 'Slow card reader', 16)) == 1)
card = fullfile(root, 'cardF');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T18:00:00.000Z', 43);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcF'));
cfg.now = @() 0;  cfg.slowCheckBytes = 1;        % instant: fast
tv.ingest.importCard(card, cfg);
assert(~any(strncmp(tv.testing.readLines(lg.notify), 'Slow card reader', 16)))

%% Fault: power lost during the archive move; the next watcher pass finishes it, nothing lost (AC-01)
card = fullfile(root, 'cardP');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T19:00:00.000Z', [51 52]);
F0 = tv.ingest.cardFiles(card);  H0 = cellfun(@tv.ingest.sha256File, {F0.path}, 'UniformOutput', false);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcP'));
cfg.archiveFaultAfter = 2;
try, tv.ingest.importCard(card, cfg); err = ''; catch e, err = e.identifier; end
assert(strcmp(err, 'tv:ingest:power') && isempty(tv.ingest.cardFiles(card)))   % card already wiped
cfg = rmfield(cfg, 'archiveFaultAfter');
a = tv.ingest.resumeArchive(cfg);
assert(numel(a) == 4 && any(strncmp(tv.testing.readLines(lg.notify), 'Archive resumed', 15)))
A = tv.testing.listFiles(cfg.archive);  A = A(cellfun(@isempty, regexp(A, '\.incomplete$')));
HA = cellfun(@tv.ingest.sha256File, A, 'UniformOutput', false);
assert(numel(A) == 6 && isempty(setxor(HA, H0)))                                % every file, once, intact
assert(isempty(dir(fullfile(cfg.staging, 'C3501325000001', '*.MP4'))))
assert(isempty(tv.ingest.resumeArchive(cfg)))                                  % nothing left to do

%% Fault: the disk fills mid-copy; the card is kept whole, and the import resumes later (AC-01, AC-02)
card = fullfile(root, 'cardD');
tv.testing.fakeCard(card, 'C3501325000002', '2026-11-14T20:00:00.000Z', [61 62]);
F0 = tv.ingest.cardFiles(card);  H0 = cellfun(@tv.ingest.sha256File, {F0.path}, 'UniformOutput', false);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcD'));
cfg.copyOpts.diskFullAfterBytes = 1;
rep = tv.ingest.importCard(card, cfg);
F1 = tv.ingest.cardFiles(card);
assert(strcmp(rep.status, 'interrupted') && numel(F1) == numel(F0))
assert(isempty(setxor(cellfun(@tv.ingest.sha256File, {F1.path}, 'UniformOutput', false), H0)))
assert(any(~cellfun(@isempty, strfind(tv.testing.readLines(lg.notify), 'disk is full'))))
cfg.copyOpts = struct();
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.status, 'done') && numel(rep.archived) == 6 && isempty(tv.ingest.cardFiles(card)))

%% Fault: the same card inserted twice; nothing is copied twice or deleted twice (AC-01)
card = fullfile(root, 'cardT');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T21:00:00.000Z', 71);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcT'));
cfg.wipeCardAfterImport = false;                                                 % so the files are still there
rep1 = tv.ingest.importCard(card, cfg);
rep2 = tv.ingest.importCard(card, cfg);
assert(numel(rep1.archived) == 3 && isempty(rep2.archived) && numel(tv.ingest.cardFiles(card)) == 3)
assert(numel(tv.testing.listFiles(cfg.archive, 'GX010071.MP4')) == 1)

%% Fault: a copy that does not match the card; the card is not wiped, and a clean retry completes (AC-02)
card = fullfile(root, 'cardX');
tv.testing.fakeCard(card, 'C3501325000002', '2026-11-14T22:00:00.000Z', [81 82]);
F0 = tv.ingest.cardFiles(card);  H0 = cellfun(@tv.ingest.sha256File, {F0.path}, 'UniformOutput', false);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcX'));
cfg.faultCorruptStaged = 'GX010082.MP4';
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.status, 'interrupted') && numel(tv.ingest.cardFiles(card)) == numel(F0))
assert(any(strncmp(tv.testing.readLines(lg.notify), 'Import error', 12)))
cfg = rmfield(cfg, 'faultCorruptStaged');
rep = tv.ingest.importCard(card, cfg);
A = cellfun(@tv.ingest.sha256File, rep.archived, 'UniformOutput', false);
assert(strcmp(rep.status, 'done') && isempty(setxor(A, H0)))

%% An unknown camera is imported as a new one, with an alert (TV-ING-02)
card = fullfile(root, 'cardC');
tv.testing.fakeCard(card, 'C9999999999999', '2026-11-14T16:00:00.000Z', 31);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcC'));
rep = tv.ingest.importCard(card, cfg);
assert(strcmp(rep.role, 'new-C9999999999999') && any(strncmp(tv.testing.readLines(lg.notify), 'New camera', 10)))

%% Too little space: the clean-up runs, then the import is refused and the card kept (TV-ING-09)
card = fullfile(root, 'cardD');
tv.testing.fakeCard(card, 'C3501325000001', '2026-11-14T17:00:00.000Z', 41);
[cfg, lg] = tv.testing.ingestConfig(fullfile(root, 'pcD'), struct('free', 1e11));
rep = tv.ingest.importCard(card, cfg);
L = tv.testing.readLines(lg.notify);
assert(strcmp(rep.status, 'refused') && any(strcmp(L, 'retention ran')) && ~isempty(tv.ingest.cardFiles(card)))

%% Overlapping recordings from both cameras make a session; a lone one waits, then goes reduced (TV-ING-20, 21)
roles = struct('serial', {'C3501325000001', 'C3501325000002'}, 'role', {'cam1', 'cam2'});
tv.testing.fakeCard(fullfile(root, 'c1'), 'C3501325000001', '2026-11-14T15:00:00.000Z', [11 12]);
tv.testing.fakeCard(fullfile(root, 'c2'), 'C3501325000002', '2026-11-14T15:00:00.500Z', [21 22]);
cfg = tv.testing.ingestConfig(fullfile(root, 'pc'));
tv.ingest.importCard(fullfile(root, 'c1'), cfg);
tv.ingest.importCard(fullfile(root, 'c2'), cfg);
R = tv.ingest.recordings(cfg.archive, roles);
A = R(strcmp({R.role}, 'cam1'));
assert(numel(R) == 4)
now0 = max([R.endUtc]) + 60;
[sess, waiting] = tv.ingest.pair(R, now0);
assert(numel(sess) == 2 && all(strcmp({sess.mode}, 'full')) && isempty(waiting))
[sess, waiting] = tv.ingest.pair(A, now0);
assert(isempty(sess) && numel(waiting) == 2)
[sess, ~] = tv.ingest.pair(A, now0 + 25 * 3600);
assert(numel(sess) == 2 && all(strcmp({sess.mode}, 'reduced')))

%% Courts by GPS: within 150 m is the same court, farther is a new one (TV-ING-22)
courts = struct('name', {'home'}, 'lat', {40.7000}, 'lon', {-74.0000}, 'indoor', {false}, 'sideFenceM', {4});
[k, courts] = tv.ingest.court(40.7009, -74.0000, courts);     % 100 m north
assert(k == 1 && numel(courts) == 1)
[k, courts] = tv.ingest.court(40.7030, -74.0000, courts);     % 333 m north
assert(k == 2 && numel(courts) == 2)
assert(tv.ingest.court(NaN, NaN, courts) == 0)                 % no fix: match the background instead
