function watch(configFile)
%WATCH  The closet PC's loop: import cards as they arrive, then process sessions (TV-ING-01).
%   Started at log-on by the Task Scheduler task that Setup-ClosetPC.ps1
%   creates (matlab -batch "tv.watch"). Every 5 s it looks for card
%   volumes with a GoPro DCIM folder, imports each new one
%   (tv.ingest.importCard), pairs recordings into sessions
%   (tv.ingest.pair), and runs the pipeline on the next waiting session,
%   one at a time (TV-OPS-04). Cards can come in any order, minutes or days
%   apart (TV-ING-03). Never exits on an error: it logs it, alerts, and
%   carries on.
if nargin < 1
    configFile = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'config', 'tennisvision.json');
end
cfg = tv.ingest.loadConfig(configFile);
state = struct('seen', {{}}, 'done', {{}});
tv.ops.notify(cfg, 'Watcher started', 'The closet PC is ready for cards.');
while true
    try
        state = tv.ingest.scanOnce(cfg, state);
    catch err
        tv.ops.notify(cfg, 'Error', sprintf('watcher: %s', err.message));
        tv.ops.light(cfg, 'error');
    end
    pause(cfg.pollSeconds);
end
end
