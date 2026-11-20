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
% files a power cut left in staging (their card already wiped) go on to the archive
icfg = cfg;  icfg.light = cfg.lightFn;
tv.ingest.resumeArchive(icfg);
% the app's answers (indoor flags, "which one is you?"), every few minutes
if ~isempty(cfg.client) && (~isfield(state, 'lastAnswers') || etime(clock, state.lastAnswers) > cfg.answersSeconds)
    state.lastAnswers = clock;
    % a held session that runs on from here (court corners answered) is a full run: lights and temperatures as below
    tv.ops.applyAnswers(cfg, cfg.client, @(f, o, p) watched(cfg, f, o, p), @(o, id, r) tv.upload.session(o, id, r, cfg.client));
end
% pair and process one waiting session
R = tv.ingest.recordings(cfg.archive, cfg.cameras);
if isempty(R), return; end
sessions = tv.ingest.pair(R, tv.util.utcSeconds(tv.util.nowUtc()));
for s = sessions(:)'
    id = sessionId(R, s);
    if any(strcmp(state.done, id)), continue; end
    out = fullfile(cfg.sessions, id);
    if exist(fullfile(out, 'session.json'), 'file'), state.done{end+1} = id; continue; end
    % TV-CAL-21: held for a doubtful court-line fit; it runs on when the corners are answered (tv.ops.applyAnswers).
    % Chris, 20 Nov: it must not stall unnoticed: the phone is reminded every cfg.heldReminderHours (12)
    if exist(fullfile(out, 'calibration', 'calibration.json'), 'file')
        state = remindHeld(cfg, state, id);
        continue
    end
    if strcmp(s.mode, 'reduced')
        cfg.notify('One camera only', sprintf('%s: only one camera''s footage arrived; reduced processing is not built yet.', id));
        state.done{end+1} = id;
        continue
    end
    cfg.lightFn('processing');
    cfg.notify('Processing started', id);
    % every chapter of each recording (22 Nov: only the first was passed, cutting long sessions short)
    files = {tv.media.joinChapters(R(s.cam1).files), tv.media.joinChapters(R(s.cam2).files)};
    pcfg = keepCalibrationAnswer(cfg.pipeline, out);
    if isempty(cfg.client), pcfg.doubtfulCalibration = 'continue'; end   % no cloud, so nobody to ask: process with the alert
    try
        res = watched(cfg, files, out, pcfg);
    catch err
        if strcmp(err.identifier, 'tv:calib:doubtful')
            % TV-CAL-21: the session waits (the pipeline has said so on the phone); its calibration
            % pictures go to the app's "court corners" page
            tv.ops.calibrationCheck(out, id, cfg.client);
            break
        end
        rethrow(err)
    end
    if ~isempty(cfg.client), tv.upload.session(out, id, res, cfg.client); end
    cfg.notify('Session ready', sprintf('%s: %s.', id, res.dataForUpload.session.headline));
    cfg.lightFn('off');
    state.done{end+1} = id;
    break                                     % one session per pass (TV-OPS-04)
end
end

function res = watched(cfg, files, out, pcfg)
% one pipeline run with the light on and the temperatures logged every minute (Chris, 16 Nov)
cfg.lightFn('processing');
tl = [];
if isfield(cfg, 'tempLogS') && ispc(), tl = tv.ops.tempLogger(cfg); end
try
    res = tv.pipeline.run(files, out, pcfg);
catch err
    if ~isempty(tl), stop(tl); delete(tl); end
    cfg.lightFn('off');
    rethrow(err)
end
if ~isempty(tl), stop(tl); delete(tl); end
cfg.lightFn('off');
end

function state = remindHeld(cfg, state, id)
% one reminder per held session every cfg.heldReminderHours (the first when the session was held)
hours = 12;  if isfield(cfg, 'heldReminderHours'), hours = cfg.heldReminderHours; end
if ~isfield(state, 'heldReminded'), state.heldReminded = struct('id', {}, 'at', {}); end
k = find(strcmp({state.heldReminded.id}, id), 1);
if isempty(k)
    state.heldReminded(end+1) = struct('id', id, 'at', clock);      % just held: the pipeline's alert went out
    return
end
if etime(clock, state.heldReminded(k).at) >= 3600 * hours
    cfg.notify('Court corners still needed', sprintf(['%s is still waiting for the court corners. ' ...
        'Open court corners in the app.'], id));
    state.heldReminded(k).at = clock;
end
end

function pcfg = keepCalibrationAnswer(pcfg, out)
% corners tapped or lines accepted for this session earlier (TV-CAL-22) stay in force when it is run
% again from here, for instance after a power cut part-way through (tv.pipeline.run saves them in run.mat)
f = fullfile(out, 'run.mat');
if ~exist(f, 'file'), return; end
S = load(f);
if ~isfield(S, 'cfg'), return; end
if isfield(S.cfg, 'corners'), pcfg.corners = S.cfg.corners; end
if isfield(S.cfg, 'calibAccepted'), pcfg.calibAccepted = S.cfg.calibAccepted; end
end

function id = sessionId(R, s)
t = s.startUtc;
d = datevec(datenum(2000, 1, 1) + t / 86400);
id = sprintf('%04d-%02d-%02dT%02d%02d%02dZ', d(1), d(2), d(3), d(4), d(5), floor(d(6)));
end
