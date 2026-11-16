function P = projectHours(stageS, synth, real)
%PROJECTHOURS  Hours a real session would take, from each stage's time on synthetic footage (Chris, 16 Nov).
%   stageS: struct, seconds per stage (probe, calib, rallies, detect, sync, recon, players,
%   metrics, outputs; missing ones count 0). synth and real: struct with durationS (footage),
%   rallyS (seconds inside rallies) and shots. Each stage scales with what drives its work:
%     probe, rallies, players   the whole footage (read end to end, or sampled across it)
%     calib                     once per session
%     detect, sync, outputs     the seconds inside rallies (full-resolution frames, the reel)
%     recon, metrics            the number of shots (one flight fit or more each)
%   P.byStage (hours per stage), P.totalH, P.table (rows: stage, synthetic s, factor, hours).
drivers = struct('probe', 'durationS', 'calib', 'once', 'rallies', 'durationS', 'detect', 'rallyS', ...
                 'sync', 'rallyS', 'recon', 'shots', 'players', 'durationS', 'metrics', 'shots', 'outputs', 'rallyS');
names = fieldnames(drivers);
P.byStage = struct();  P.table = {};  P.totalH = 0;
for i = 1:numel(names)
    n = names{i};  s = 0;
    if isfield(stageS, n), s = stageS.(n); end
    d = drivers.(n);
    if strcmp(d, 'once'), f = 1; else, f = real.(d) / max(synth.(d), eps); end
    h = s * f / 3600;
    P.byStage.(n) = h;  P.totalH = P.totalH + h;
    P.table(end+1, :) = {n, s, f, h};
end
end
