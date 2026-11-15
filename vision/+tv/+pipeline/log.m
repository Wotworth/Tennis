function log(outDir, stage, msg)
%LOG  One timestamped line in the session's plain-text log (TV-ARCH-22), also printed.
d = fullfile(outDir, 'logs');
if ~exist(d, 'dir'), mkdir(d); end
line = sprintf('%s  %-9s %s', tv.util.nowUtc(), stage, msg);
fid = fopen(fullfile(d, 'session.log'), 'a');  fprintf(fid, '%s\n', line);  fclose(fid);
fprintf('%s\n', line);
end
