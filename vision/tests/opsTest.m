% The closet PC's heat watch (Chris, 16 Nov): temperatures, the log, the slow-down, the weekly peaks.
root = tempname();  mkdir(root);
hot = struct('cpu', 95, 'gpu', 70, 'gpuW', 200, 'gpuLimitW', 200);
cool = struct('cpu', 60, 'gpu', 55, 'gpuW', 120, 'gpuLimitW', 200);

%% nvidia-smi's answer and a PowerShell number parse
[t, w, l] = tv.ops.parseGpuQuery(sprintf('67, 187.45, 200.00\n'));
assert(t == 67 && abs(w - 187.45) < 1e-9 && l == 200)
[t, w, l] = tv.ops.parseGpuQuery('');
assert(isnan(t) && isnan(w) && isnan(l))
assert(tv.ops.parseNumber(sprintf('71,5\r\n')) == 71.5 && isnan(tv.ops.parseNumber('no sensor')))

%% temps() reads the GPU from nvidia-smi and the CPU from the sensors; missing tools give NaN
T = tv.ops.temps(tv.testing.fakeShell({'nvidia-smi', 'powershell'}, {'64, 150, 200', '78.2'}));
assert(T.gpu == 64 && T.cpu == 78.2 && T.gpuLimitW == 200)
T = tv.ops.temps(tv.testing.fakeShell({}, {}));
assert(isnan(T.gpu) && isnan(T.cpu))

%% The log gets a line a call, and the peaks over the week come back out
d = fullfile(root, 'logs1');
tv.ops.tempLog(d, @() cool, 'detect');
tv.ops.tempLog(d, @() hot, 'detect');
tv.ops.tempLog(d, @() cool, 'recon');
P = tv.ops.tempPeaks(d, 7);
assert(P.cpu == 95 && P.gpu == 70)
today = tv.util.nowUtc();
L = regexp(strtrim(fileread(fullfile(d, sprintf('temps-%s.csv', today(1:10))))), '\n', 'split');
assert(numel(L) == 4 && strncmp(L{1}, 'utc,stage,cpuC', 14))

%% Too hot: processing pauses until both are 5 C under their limits, and the pauses are logged
seq = {hot, hot, hot, cool};  i = javaObject('java.util.concurrent.atomic.AtomicInteger', 0);
read = @() seq{min(double(i.incrementAndGet()), numel(seq))};
waited = tv.ops.thermalGuard(struct('logs', fullfile(root, 'logs2')), read, @(s) 0);
assert(waited == 90)
assert(tv.ops.thermalGuard(struct(), @() cool, @(s) 0) == 0)

%% Hot for too long: it carries on after the longest wait and alerts once
calls = containers.Map();  calls('notify') = {};
cfg = struct('tempMaxWaitS', 120, 'notify', @(a, b) tv.testing.recordCall(calls, 'notify', a, []));
waited = tv.ops.thermalGuard(cfg, @() hot, @(s) 0);
n = calls('notify');
assert(waited == 120 && numel(n) == 1 && strcmp(n{1}, 'Running hot'))

%% The 2-hour projection scales each stage by what drives it
st = struct('probe', 10, 'calib', 60, 'rallies', 5, 'detect', 300, 'sync', 20, 'recon', 90, 'players', 40, 'metrics', 3, 'outputs', 30);
syn = struct('durationS', 26, 'rallyS', 13, 'shots', 9);
real = struct('durationS', 7200, 'rallyS', 1800, 'shots', 550);
P = tv.ops.projectHours(st, syn, real);
assert(abs(P.byStage.calib - 60 / 3600) < 1e-12)                    % once a session
assert(abs(P.byStage.detect - 300 * 1800 / 13 / 3600) < 1e-9)       % by rally seconds
assert(abs(P.byStage.recon - 90 * 550 / 9 / 3600) < 1e-9)           % by shots
assert(abs(P.totalH - sum(cell2mat(P.table(:, 4)))) < 1e-12 && size(P.table, 1) == 9)
