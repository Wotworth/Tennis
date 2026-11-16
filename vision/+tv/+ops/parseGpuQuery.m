function [tempC, powerW, limitW] = parseGpuQuery(text)
%PARSEGPUQUERY  "temperature, power draw, power limit" from nvidia-smi's CSV (first GPU).
tempC = NaN;  powerW = NaN;  limitW = NaN;
lines = regexp(strtrim(text), '\r?\n', 'split');
if isempty(lines) || isempty(lines{1}), return; end
v = str2double(strtrim(strsplit(lines{1}, ',')));
if numel(v) >= 1, tempC = v(1); end
if numel(v) >= 2, powerW = v(2); end
if numel(v) >= 3, limitW = v(3); end
end
