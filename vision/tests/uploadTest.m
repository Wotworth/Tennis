% Upload to the cloud, and applying the app's answers (TV-UP-01, 02, TV-PLY-07, Chris 15 Nov).
root = tempname();  mkdir(root);
out = fullfile(root, 'session');  mkdir(fullfile(out, 'clips'));
for f = {'session.json', 'shots.json', 'rallies.json', 'reel_1080p.mp4', 'clips/rally_01.mp4'}
    fid = fopen(fullfile(out, f{1}), 'w');  fprintf(fid, 'content of %s', f{1});  fclose(fid);
end
mkdir(fullfile(out, 'stages'));  fclose(fopen(fullfile(out, 'stages', 'calib.mat'), 'w'));
res.summaryForUpload = struct('startUtc', '2026-11-14T15:00:00.000Z', 'mode', 'full');
res.dataForUpload = struct('session', struct('headline', '9 shots'), 'rallies', [], 'shots', [], 'stats', [], 'complete', true);

%% Every app file goes up through its link; the PC's own stages do not
[c, log] = tv.testing.fakeClient();
tv.upload.session(out, 's1', res, c);
sent = cellfun(@(x) x{2}, log('file'), 'UniformOutput', false);
assert(numel(sent) == 5 && all(cellfun(@isempty, strfind(sent, 'stages'))))
P = log('put');  assert(strcmp(P{end}{1}, '/sessions/s1/data') && P{end}{2}.complete)

%% A file the Worker already holds (same SHA-256) is not sent again (TV-UP-02)
[c, log] = tv.testing.fakeClient(struct('conditions', [], 'identity', []), {'reel_1080p.mp4'});
rep = tv.upload.session(out, 's1', res, c);
assert(any(strcmp(rep.skipped, 'reel_1080p.mp4')) && numel(log('file')) == 4)

%% Big files go in parts (multipart above 100 MB)
big = fullfile(out, 'trajectories.json.gz');
fid = fopen(big, 'w');  fwrite(fid, zeros(101 * 2^20, 1, 'uint8'));  fclose(fid);
[c, log] = tv.testing.fakeClient();
tv.upload.session(out, 's1', res, c, struct('partBytes', 40 * 2^20));
assert(numel(log('bytes')) == 3 && numel(log('urlput')) == 2)       % create + complete, 3 parts
delete(big);

%% An indoor flag reruns from physics with indoor air; an identity answer reruns the metrics
cfg.sessions = root;  cfg.notify = @(t, m) [];
pc = tv.pipeline.defaults();  pc = rmfield(pc, 'notify');
pc.weather = struct('tempC', 5, 'relHumidity', 0.9, 'pressurePa', 101000, 'wind10', [4 0]);
files = {'a.MP4', 'b.MP4'};  S0 = struct('cfg', pc);
save(fullfile(out, 'run.mat'), 'files');  save(fullfile(out, 'run.mat'), '-struct', 'S0', '-append');
pending.conditions = struct('id', 7, 'sessionId', 'session', 'indoor', true);
pending.identity = struct('id', 3, 'sessionId', 'session', 'label', 'Player B');
[c, log] = tv.testing.fakeClient(pending);
calls = containers.Map();  calls('cfgs') = {};
runFn = @(f, o, p) tv.testing.recordCall(calls, 'cfgs', p, res);
up = @(o, id, r) [];
done = tv.ops.applyAnswers(cfg, c, runFn, up);
cf = calls('cfgs');
assert(numel(done) == 2 && numel(cf) == 2)
assert(cf{1}.indoor && cf{1}.weather.tempC == pc.indoorDefaults.tempC && cf{1}.weather.pressurePa == 101000)
assert(strcmp(cf{2}.chrisLabel, 'Player B'))
posted = cellfun(@(x) x{1}, log('post'), 'UniformOutput', false);
assert(any(strcmp(posted, '/conditions/7/applied')) && any(strcmp(posted, '/identity/3/applied')))

%% What goes to the cloud holds no court name, photo or heart rate
txt = jsonencode(res.dataForUpload);
assert(isempty(regexpi(txt, 'court|photo|heart|bpm', 'once')))

