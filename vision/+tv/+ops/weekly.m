function text = weekly(cfg, client, st, stats)
%WEEKLY  The weekly "all OK" message (TV-OPS-06, Chris 15 Nov).
%   Disk use and the projected use at the current playing rate, sessions
%   processed this week, warnings, each retraining since last week (old
%   versus new test-set recall and precision, promoted or why not), and the
%   number of open "looks wrong" flags, and the week's peak CPU and GPU
%   temperatures (Chris, 16 Nov). stats: struct with sessionsThisWeek,
%   warnings (cell), diskFreeGB, diskTotalGB, gbPerWeek.
lines = {sprintf('%d sessions processed this week.', stats.sessionsThisWeek)};
used = stats.diskTotalGB - stats.diskFreeGB;
weeksLeft = stats.diskFreeGB / max(stats.gbPerWeek, eps);
lines{end+1} = sprintf('Archive: %.0f of %.0f GB used; about %.0f weeks left at this rate.', used, stats.diskTotalGB, weeksLeft);
if exist(st.history, 'file')
    H = jsondecode(fileread(st.history));
    cutoff = datenum(tv.util.nowUtc(), 'yyyy-mm-ddTHH:MM:SS') - 7;
    for h = H(:)'
        if datenum(h.utc(1:10), 'yyyy-mm-dd') < cutoff, continue; end
        verdict = 'kept the old model';  if h.promoted, verdict = 'promoted'; end
        lines{end+1} = sprintf('Retrained: recall %.1f%% -> %.1f%%, precision %.1f%% -> %.1f%% on %d test frames: %s (%s).', ...
            100 * h.oldRecall, 100 * h.newRecall, 100 * h.oldPrecision, 100 * h.newPrecision, h.testFrames, verdict, h.why); %#ok<AGROW>
    end
end
open = client.getJson('/flags?status=open');
if iscell(open), open = [open{:}]; end
nWrong = 0;  if ~isempty(open), nWrong = nnz(strcmp({open.kind}, 'looks wrong')); end
lines{end+1} = sprintf('%d open "looks wrong" flag%s.', nWrong, ifelse(nWrong == 1, '', 's'));
% peak temperatures this week (Chris, 16 Nov)
if isfield(cfg, 'logs') && exist(cfg.logs, 'dir')
    P = tv.ops.tempPeaks(cfg.logs, 7);
    if isfinite(P.cpu) || isfinite(P.gpu)
        lines{end+1} = sprintf('Peak temperatures: CPU %.0f C, GPU %.0f C.', P.cpu, P.gpu);
    end
end
for w = stats.warnings(:)', lines{end+1} = ['Warning: ' w{1}]; end %#ok<AGROW>
text = strjoin(lines, ' ');
cfg.notify('Weekly', text);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
