function [cfg, log] = ingestConfig(root, opts)
%INGESTCONFIG  An import configuration that records alerts and light states (tests).
%   log is a handle-free struct path: messages go to <root>/notify.txt and
%   light states to <root>/light.txt, read back with tv.testing.readLines.
if nargin < 2, opts = struct(); end
if ~exist(root, 'dir'), mkdir(root); end
cfg.staging = fullfile(root, 'staging');
cfg.archive = fullfile(root, 'archive');
cfg.cameras = struct('serial', {'C3501325000001', 'C3501325000002'}, 'role', {'cam1', 'cam2'});
cfg.wipeCardAfterImport = true;
cfg.minFreeFraction = 0.15;
log.notify = fullfile(root, 'notify.txt');  log.light = fullfile(root, 'light.txt');
cfg.notify = @(title, text) appendLine(log.notify, [title ': ' text]);
cfg.light = @(state) appendLine(log.light, state);
if isfield(opts, 'free'), cfg.freeSpace = @(f) deal(opts.free, 1e12); else, cfg.freeSpace = @(f) deal(5e11, 1e12); end
cfg.retention = @() appendLine(log.notify, 'retention ran');
cfg.copyOpts = struct();
if isfield(opts, 'faultAfterBytes'), cfg.copyOpts.faultAfterBytes = opts.faultAfterBytes; end
end

function appendLine(f, s)
fid = fopen(f, 'a');  fprintf(fid, '%s\n', s);  fclose(fid);
end
