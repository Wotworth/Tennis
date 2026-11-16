function P = tempPeaks(logDir, days, today)
%TEMPPEAKS  Peak CPU and GPU temperatures over the last DAYS days of temps-*.csv (weekly message).
%   P.cpu, P.gpu (C, NaN if no readings) and P.cpuAt, P.gpuAt (UTC time of each peak).
if nargin < 3, today = tv.util.nowUtc(); end
P = struct('cpu', NaN, 'gpu', NaN, 'cpuAt', '', 'gpuAt', '');
t0 = datenum(today(1:10), 'yyyy-mm-dd') - days + 1;
F = dir(fullfile(logDir, 'temps-*.csv'));
for f = F(:)'
    d = regexp(f.name, '\d{4}-\d{2}-\d{2}', 'match', 'once');
    if isempty(d) || datenum(d, 'yyyy-mm-dd') < t0, continue; end
    L = regexp(fileread(fullfile(logDir, f.name)), '\r?\n', 'split');
    for i = 2:numel(L)
        c = strsplit(L{i}, ',');
        if numel(c) < 4, continue; end
        cpu = str2double(c{3});  gpu = str2double(c{4});
        if isfinite(cpu) && ~(cpu <= P.cpu), P.cpu = cpu; P.cpuAt = c{1}; end
        if isfinite(gpu) && ~(gpu <= P.gpu), P.gpu = gpu; P.gpuAt = c{1}; end
    end
end
end
