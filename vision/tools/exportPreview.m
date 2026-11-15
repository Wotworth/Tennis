function exportPreview(outDir, S)
%EXPORTPREVIEW  Write a synthetic data session (tv.synth.dataSession) as the pipeline's files.
%   outDir gets session.json, shots.json, rallies.json, trajectories.json
%   (positions to the centimetre) and hr.json. These are the app's bundled
%   sample and the input of tools/previewPlots.m. SYNTHETIC: labelled so in
%   session.json.
if ~exist(outDir, 'dir'), mkdir(outDir); end
tv.util.writeJson(fullfile(outDir, 'session.json'), S.session);
tv.util.writeJson(fullfile(outDir, 'shots.json'), S.shots);
tv.util.writeJson(fullfile(outDir, 'rallies.json'), S.rallies);
T = S.trajectories;
for k = 1:numel(T)
    T(k).xyz = round(T(k).xyz * 100) / 100;
    T(k).noSpin = round(T(k).noSpin(1:2:end, :) * 100) / 100;
end
[T.dtNoSpin] = deal(2 * T(1).dt);
tv.util.writeJson(fullfile(outDir, 'trajectories.json'), T);
tv.util.writeJson(fullfile(outDir, 'hr.json'), S.hr);
end
