function L = readLines(f)
%READLINES  The lines of a text file (empty if it does not exist).
L = {};
if ~exist(f, 'file'), return; end
L = strsplit(strtrim(fileread(f)), sprintf('\n'));
end
