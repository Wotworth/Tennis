function done = applyAnswers(cfg, client, runFn, uploadFn)
%APPLYANSWERS  Apply what the app sent back, then re-upload (TV-PLY-07, Chris 15 Nov).
%   Checked every few minutes by the watcher.
%   - indoor flags (GET /conditions/pending): the session reruns from the
%     physics stage with indoor settings: wind 0, the configured indoor
%     temperature and humidity, pressure still from the weather
%     (TV-IND-01). Earlier stages are reused from their manifests.
%   - "which one is you?" answers (GET /identity/pending): only the metrics
%     stage reruns, with the chosen player as Chris.
%   - court corners (GET /calibration/answered, TV-CAL-22): a session held for a doubtful
%     court-line fit runs on once every camera asked about has its answer: the four tapped
%     corners of the doubles court (the pose then comes from tv.calib.fromCorners), or "the
%     lines are right" (the fit stands). If the taps do not make a court the question is sent
%     again and the session stays held.
%   Each answer is marked applied only after the re-upload succeeded.
%   runFn(files, outDir, cfg) runs the pipeline (tv.pipeline.run);
%   uploadFn(outDir, sessionId, result) uploads; both replaceable in tests.
done = {};
conds = asList(client.getJson('/conditions/pending'));
for c = conds
    a = c{1};
    [files, pcfg, outDir] = savedRun(cfg, a.sessionId);
    if isempty(files), continue; end
    pcfg.indoor = logical(a.indoor);
    if pcfg.indoor
        pcfg.weather.tempC = pcfg.indoorDefaults.tempC;
        pcfg.weather.relHumidity = pcfg.indoorDefaults.relHumidity;
    end
    res = runFn(files, outDir, pcfg);
    uploadFn(outDir, a.sessionId, res);
    client.postJson(sprintf('/conditions/%d/applied', a.id), struct());
    done{end+1} = sprintf('%s indoor=%d', a.sessionId, pcfg.indoor); %#ok<AGROW>
end
ids = asList(client.getJson('/identity/pending'));
for c = ids
    a = c{1};
    [files, pcfg, outDir] = savedRun(cfg, a.sessionId);
    if isempty(files), continue; end
    pcfg.chrisLabel = a.label;
    res = runFn(files, outDir, pcfg);
    uploadFn(outDir, a.sessionId, res);
    client.postJson(sprintf('/identity/%d/applied', a.id), struct());
    done{end+1} = sprintf('%s chris=%s', a.sessionId, a.label); %#ok<AGROW>
end
cal = asList(client.getJson('/calibration/answered'));
sess = cellfun(@(a) a.sessionId, cal, 'UniformOutput', false);
for id = unique(sess)
    A = cal(strcmp(sess, id{1}));
    [files, pcfg, outDir] = savedRun(cfg, id{1});
    if isempty(files), continue; end
    if ~isfield(pcfg, 'corners'), pcfg.corners = {[], []}; end
    if ~isfield(pcfg, 'calibAccepted'), pcfg.calibAccepted = [false false]; end
    for c = A
        a = c{1};
        if strcmp(a.answer, 'corners')
            % the app's taps are in the sent picture's pixels from its top-left corner (tv.calib.writeCheck)
            pcfg.corners{a.cam} = tapMatrix(a.corners) / a.scale + 0.5;
            pcfg.calibAccepted(a.cam) = false;
        else
            pcfg.corners{a.cam} = [];
            pcfg.calibAccepted(a.cam) = true;
        end
    end
    again = false;
    try
        res = runFn(files, outDir, pcfg);
    catch err
        if ~strcmp(err.identifier, 'tv:calib:doubtful'), rethrow(err); end
        again = true;
    end
    if ~again
        uploadFn(outDir, id{1}, res);
        headline = '';
        if isfield(res, 'dataForUpload') && isfield(res.dataForUpload, 'session') && isfield(res.dataForUpload.session, 'headline')
            headline = [': ' res.dataForUpload.session.headline];
        end
        cfg.notify('Session ready', sprintf('%s%s.', id{1}, headline));
    end
    for c = A, client.postJson(sprintf('/calibration/%d/applied', c{1}.id), struct()); end
    if again
        tv.ops.calibrationCheck(outDir, id{1}, client);   % still doubtful: ask again
        done{end+1} = sprintf('%s corners asked again', id{1}); %#ok<AGROW>
    else
        done{end+1} = sprintf('%s corners', id{1}); %#ok<AGROW>
    end
end
end

function T = tapMatrix(x)
% four [x y] pairs, however the JSON reader shaped them
if iscell(x), x = cell2mat(cellfun(@(r) r(:)', x(:), 'UniformOutput', false)); end
T = double(x);
if ~isequal(size(T), [4 2]), T = reshape(T, [], 2); end
end

function L = asList(x)
% webread gives a struct array (or a cell array when fields differ)
if isempty(x), L = {}; elseif iscell(x), L = x(:)'; else, L = num2cell(x(:)'); end
end

function [files, pcfg, outDir] = savedRun(cfg, id)
% the files and settings the session was processed with (tv.pipeline.run saves run.mat)
outDir = fullfile(cfg.sessions, id);
files = {};  pcfg = [];
f = fullfile(outDir, 'run.mat');
if ~exist(f, 'file'), return; end
S = load(f);
files = S.files;  pcfg = S.cfg;
pcfg.notify = cfg.notify;
end
