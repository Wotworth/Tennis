function T = tempLog(logDir, readFn, stage)
%TEMPLOG  Append one line of temperatures to logs/temps-YYYY-MM-DD.csv (Chris, 16 Nov).
%   Called every minute while processing (tv.ops.tempLogger). Columns: UTC time, stage,
%   CPU C, GPU C, GPU W, GPU limit W. readFn: tv.ops.temps by default.
if nargin < 2 || isempty(readFn), readFn = @tv.ops.temps; end
if nargin < 3, stage = ''; end
T = readFn();
if ~exist(logDir, 'dir'), mkdir(logDir); end
now = tv.util.nowUtc();
f = fullfile(logDir, sprintf('temps-%s.csv', now(1:10)));
new = ~exist(f, 'file');
fid = fopen(f, 'a');
if new, fprintf(fid, 'utc,stage,cpuC,gpuC,gpuW,gpuLimitW\n'); end
fprintf(fid, '%s,%s,%.1f,%.1f,%.1f,%.1f\n', now, stage, T.cpu, T.gpu, T.gpuW, T.gpuLimitW);
fclose(fid);
end
