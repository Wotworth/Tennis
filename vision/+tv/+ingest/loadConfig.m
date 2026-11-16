function cfg = loadConfig(file)
%LOADCONFIG  The PC's settings (config/tennisvision.json, never in Git) as the import code wants them.
s = jsondecode(fileread(file));
cfg.staging = s.folders.staging;
cfg.archive = s.folders.archive;
cfg.sessions = s.folders.sessions;
cfg.logs = s.folders.logs;
cfg.cameras = s.cameras;
cfg.courts = s.courts;
cfg.wipeCardAfterImport = s.wipeCardAfterImport;
cfg.minFreeFraction = s.thresholds.freeSpaceMinFraction;
cfg.alerts = s.alerts;
cfg.retentionDays = s.retentionDays;
cfg.light = struct('tool', '');
if isfield(s, 'statusLight') && isfield(s.statusLight, 'tool'), cfg.light.tool = s.statusLight.tool; end
cfg.pollSeconds = 5;
cfg.cardPattern = 'DCIM';
cfg.cardRoots = {};                         % empty: every drive letter D: to Z:
if isfield(s, 'cardRoots'), cfg.cardRoots = s.cardRoots; end
cfg.notify = @(title, text) tv.ops.notify(cfg, title, text);
cfg.lightFn = @(state) tv.ops.light(cfg, state);
cfg.freeSpace = @tv.ingest.freeSpace;
cfg.retention = @() tv.ops.retention(cfg);
cfg.copyOpts = struct();
cfg.pipeline = tv.pipeline.defaults();
cfg.pipeline.notify = cfg.notify;
if isfield(s, 'indoorDefaults'), cfg.pipeline.indoorDefaults = s.indoorDefaults; end
% the closet PC (Chris, 16 Nov): heat limits, temperature log, slow-port check
pc = struct('gpuPowerCapW', 200, 'tempLimitC', struct('cpu', 90, 'gpu', 80), 'tempLogS', 60, 'slowReaderMBps', 45);
if isfield(s, 'pc'), f = fieldnames(s.pc); for i = 1:numel(f), pc.(f{i}) = s.pc.(f{i}); end, end
cfg.pc = pc;
cfg.tempLimitC = pc.tempLimitC;  cfg.tempLogS = pc.tempLogS;  cfg.slowReaderMBps = pc.slowReaderMBps;
g = struct('tempLimitC', pc.tempLimitC, 'logs', cfg.logs, 'notify', cfg.notify);
cfg.pipeline.thermalGuard = @() tv.ops.thermalGuard(g);
% the cloud API (TV-PH-4): endpoint in the config, write token in secrets.local.json
cfg.client = [];
cfg.answersSeconds = 300;                   % TV-PLY-07: check for app answers every 5 minutes
sf = fullfile(fileparts(file), 'secrets.local.json');
if isfield(s, 'upload') && ~strncmp(s.upload.endpoint, 'FILL', 4) && exist(sf, 'file')
    sec = jsondecode(fileread(sf));
    if isfield(sec, 'uploadToken') && ~isempty(sec.uploadToken)
        cfg.client = tv.upload.httpClient(s.upload.endpoint, sec.uploadToken);
    end
end
end
