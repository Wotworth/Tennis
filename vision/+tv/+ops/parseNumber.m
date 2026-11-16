function x = parseNumber(text)
%PARSENUMBER  The first number in a command's output (NaN if none; a decimal comma is accepted).
t = regexp(strrep(text, ',', '.'), '-?\d+(\.\d+)?', 'match', 'once');
x = NaN;  if ~isempty(t), x = str2double(t); end
end
