function counts = rejects(outDir, ballLog, dropped, people)
%REJECTS  The session's reject log (TV-ADJ-06): what was not analysed, and why.
%   ballLog: cell per rally of tv.recon.gateTracks logs (with .rally);
%   dropped: cell per rally of flights the fit dropped (tv.recon.segments);
%   people: tv.players.keepCourt's log.
%   Writes outDir/rejects/rejects.csv (one row per rejected detection, flight
%   or person) and outDir/rejects/rejects.html (counts by reason and a top-down
%   plot; self-contained, so the Worker can serve it as one file). Both upload
%   with the session (TV-API-06: private, through the Worker).
%   counts: struct array reason, n (also in session.json for the app).
d = fullfile(outDir, 'rejects');
if ~exist(d, 'dir'), mkdir(d); end
rows = {};
reasons = {};
for r = 1:numel(ballLog)
    for g = ballLog{r}(:)'
        rows{end+1} = sprintf('ball,%d,%d,%d,%.4f,%.1f,%.1f,%s,%d,%s,%.2f', r, g.cam, g.frame, g.t, g.u, g.v, ...
            xyz(g.X), g.track, g.reason, g.errPx); %#ok<AGROW>
        reasons{end+1} = g.reason; %#ok<AGROW>
    end
end
for r = 1:numel(dropped)
    for s = dropped{r}(:)'
        rows{end+1} = sprintf('flight,%d,,,%.4f,,,%s,,implausible flight (%.1f px; from %.3f to %.3f s),%.2f', ...
            r, min(s.t), xyz(nan(1, 3)), s.rmsPx, min(s.t), max(s.t), s.rmsPx); %#ok<AGROW>
        reasons{end+1} = 'implausible flight'; %#ok<AGROW>
    end
end
for p = people(:)'
    rows{end+1} = sprintf('person,,,,%.2f,,,%.2f,%.2f,,%d,%s (%.0f%% inside; to %.1f s),', ...
        p.tStart, p.x, p.y, p.track, p.reason, 100 * p.insideFrac, p.tEnd); %#ok<AGROW>
    reasons{end+1} = p.reason; %#ok<AGROW>
end
fid = fopen(fullfile(d, 'rejects.csv'), 'w');
fprintf(fid, 'kind,rally,camera,frame,time_s,u_px,v_px,x_m,y_m,z_m,track,reason,error_px\n');
fprintf(fid, '%s\n', rows{:});
fclose(fid);
% counts by reason (the bracketed detail stripped)
counts = struct('reason', {}, 'n', {});
if ~isempty(reasons)
    base = regexprep(reasons, ' \(.*$', '');
    [u, ~, j] = unique(base);
    n = accumarray(j(:), 1)';
    counts = struct('reason', u, 'n', num2cell(n));
end
% the html report
L = {'<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">', ...
     '<title>Rejected detections</title><style>body{background:#000;color:#fff;font-family:sans-serif;margin:16px}', ...
     'td,th{padding:4px 12px;text-align:left}th{color:#8a8a8a;font-weight:normal}img{max-width:100%}</style></head><body>', ...
     '<h1>Rejected detections</h1>', ...
     '<p>What this session did not analyse, and why (Chris''s court only, TV-ADJ). The full list is rejects.csv.</p>', ...
     '<table><tr><th>Reason</th><th>Count</th></tr>'};
for c = counts(:)'
    L{end+1} = sprintf('<tr><td>%s</td><td>%d</td></tr>', c.reason, c.n); %#ok<AGROW>
end
L{end+1} = '</table>';
png = fullfile(d, 'rejects.png');
if ~exist('OCTAVE_VERSION', 'builtin') && plotTopDown(png, ballLog, people)
    fid = fopen(png, 'r');  b = fread(fid, Inf, 'uint8=>uint8');  fclose(fid);
    L{end+1} = sprintf('<h2>Seen from above</h2><img alt="rejected points on and around the court" src="data:image/png;base64,%s">', ...
        matlab.net.base64encode(b));
end
L{end+1} = '</body></html>';
fid = fopen(fullfile(d, 'rejects.html'), 'w', 'n', 'UTF-8');  fprintf(fid, '%s\n', L{:});  fclose(fid);
end

function s = xyz(X)
if any(isnan(X)), s = ',,'; else, s = sprintf('%.2f,%.2f,%.2f', X); end
end

function ok = plotTopDown(png, ballLog, people)
% rejected 3D points and people, over the court lines, coloured by reason
ok = false;
pts = [];  why = {};
for r = 1:numel(ballLog)
    for g = ballLog{r}(:)'
        if all(isfinite(g.X)), pts(end+1, :) = g.X(1:2); why{end+1} = g.reason; end %#ok<AGROW>
    end
end
if isempty(pts) && isempty(people), return; end
f = figure('Visible', 'off', 'Color', 'k', 'Position', [0 0 900 600]);
ax = axes(f, 'Color', 'k', 'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6]);  hold(ax, 'on');  axis(ax, 'equal');
L = tv.court.lines();
for k = 1:size(L, 1), plot(ax, L(k, [1 3]), L(k, [2 4]), 'w-'); end
u = unique(why);
col = lines(max(1, numel(u)));
for k = 1:numel(u)
    m = strcmp(why, u{k});
    plot(ax, pts(m, 1), pts(m, 2), '.', 'Color', col(k, :), 'DisplayName', u{k});
end
if ~isempty(people)
    plot(ax, [people.x], [people.y], 'o', 'Color', [1 0.4 0.8], 'DisplayName', 'people off court');
end
legend(ax, 'TextColor', 'w', 'Color', 'k', 'Location', 'eastoutside');
xlabel(ax, 'x (m)');  ylabel(ax, 'y (m)');
exportgraphics(f, png, 'Resolution', 110);  close(f);
ok = true;
end
