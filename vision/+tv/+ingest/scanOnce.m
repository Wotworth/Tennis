function state = scanOnce(cfg, state)
%SCANONCE  One pass of the watcher: import new cards, pair recordings, process one session.
roots = cfg.cardRoots;
if isempty(roots)
    roots = arrayfun(@(c) [c ':\'], 'D':'Z', 'UniformOutput', false);
end
present = {};
for r = roots(:)'
    if exist(fullfile(r{1}, cfg.cardPattern), 'dir') && ~isempty(tv.ingest.cardFiles(r{1}))
        present{end+1} = r{1}; %#ok<AGROW>
    end
end
% a card is new when it appears (it may be re-inserted after a pull: import resumes)
for r = present
    if any(strcmp(state.seen, r{1})), continue; end
    state.seen{end+1} = r{1};
    icfg = cfg;  icfg.light = cfg.lightFn;
    tv.ingest.importCard(r{1}, icfg);
end
state.seen = intersect(state.seen, present);
% pair and process one waiting session
R = tv.ingest.recordings(cfg.archive, cfg.cameras);
if isempty(R), return; end
sessions = tv.ingest.pair(R, tv.util.utcSeconds(tv.util.nowUtc()));
for s = sessions(:)'
    id = sessionId(R, s);
    if any(strcmp(state.done, id)), continue; end
    out = fullfile(cfg.sessions, id);
    if exist(fullfile(out, 'session.json'), 'file'), state.done{end+1} = id; continue; end
    if strcmp(s.mode, 'reduced')
        cfg.notify('One camera only', sprintf('%s: only one camera''s footage arrived; reduced processing is not built yet.', id));
        state.done{end+1} = id;
        continue
    end
    cfg.lightFn('processing');
    cfg.notify('Processing started', id);
    files = {R(s.cam1).files{1}, R(s.cam2).files{1}};
    res = tv.pipeline.run(files, out, cfg.pipeline);
    cfg.notify('Session ready', sprintf('%s: %d rallies, %d shots.', id, numel(res.rallies), numel(res.shots)));
    cfg.lightFn('off');
    state.done{end+1} = id;
    break                                     % one session per pass (TV-OPS-04)
end
end

function id = sessionId(R, s)
t = s.startUtc;
d = datevec(datenum(2000, 1, 1) + t / 86400);
id = sprintf('%04d-%02d-%02dT%02d%02d%02dZ', d(1), d(2), d(3), d(4), d(5), floor(d(6)));
end
