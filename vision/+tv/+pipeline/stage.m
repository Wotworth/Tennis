function out = stage(outDir, name, key, fn)
%STAGE  Run one pipeline stage, or reuse its saved result (TV-ARCH-21, TV-OPS-02).
%   Each stage saves its result (stages/<name>.mat) and a manifest
%   (stages/<name>.manifest.json: key, code version, start and end time,
%   status). When the manifest says the same key and code version finished
%   OK, the saved result is loaded instead of running the stage again; so a
%   crash or power cut resumes from the last finished stage, and new code
%   reruns only the stages it touches. key: text that changes whenever the
%   stage's inputs or parameters change.
d = fullfile(outDir, 'stages');
if ~exist(d, 'dir'), mkdir(d); end
mf = fullfile(d, [name '.manifest.json']);
mat = fullfile(d, [name '.mat']);
code = tv.util.codeVersion();
h = tv.util.hashText(key);
if exist(mf, 'file') && exist(mat, 'file')
    m = jsondecode(fileread(mf));
    if strcmp(m.status, 'ok') && strcmp(m.key, h) && strcmp(m.code, code)
        tv.pipeline.log(outDir, name, 'reused the saved result');
        S = load(mat);  out = S.out;  return
    end
end
started = tv.util.nowUtc();
tv.pipeline.log(outDir, name, 'started');
tv.util.writeJson(mf, struct('stage', name, 'key', h, 'code', code, 'started', started, 'finished', '', 'status', 'running'));
t = tic;
out = fn();
save(mat, 'out');
tv.util.writeJson(mf, struct('stage', name, 'key', h, 'code', code, 'started', started, ...
    'finished', tv.util.nowUtc(), 'seconds', toc(t), 'status', 'ok'));
tv.pipeline.log(outDir, name, sprintf('finished in %.1f s', toc(t)));
end
