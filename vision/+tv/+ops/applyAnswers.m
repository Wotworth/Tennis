function done = applyAnswers(cfg, client, runFn, uploadFn)
%APPLYANSWERS  Apply what the app sent back, then re-upload (TV-PLY-07, Chris 15 Nov).
%   Checked every few minutes by the watcher.
%   - indoor flags (GET /conditions/pending): the session reruns from the
%     physics stage with indoor settings: wind 0, the configured indoor
%     temperature and humidity, pressure still from the weather
%     (TV-IND-01). Earlier stages are reused from their manifests.
%   - "which one is you?" answers (GET /identity/pending): only the metrics
%     stage reruns, with the chosen player as Chris.
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
