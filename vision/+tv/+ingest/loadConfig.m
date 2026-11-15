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
end
