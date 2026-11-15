function out = generate(folder, sc)
%GENERATE  A complete synthetic session on disk, with its answers (TV-TST-01).
%   generate(folder) writes, for the default scenario:
%     <folder>/card1/DCIM/100GOPRO/GX010011.MP4   camera 1 (as on its SD card)
%     <folder>/card2/DCIM/100GOPRO/GX010012.MP4   camera 2
%     <folder>/truth.json                          everything the pipeline must recover
%   Returns a struct with the file paths, cameras and truth.
if nargin < 2, sc = tv.synth.defaultScenario(); end
tv.util.seed(sc.seed);
cams  = tv.synth.cameras(sc);
truth = tv.synth.planSession(sc);
out.files = cell(1, 2);
for k = 1:2
    out.files{k} = tv.synth.writeRecording(fullfile(folder, sprintf('card%d', k), 'DCIM', '100GOPRO'), cams(k), sc, truth, k);
end
out.cams = cams;  out.truth = truth;  out.scenario = sc;
t = rmfield(truth, {'T', 'ballP'});
t.cameras = arrayfun(@(c) struct('serial', c.serial, 'pos', c.pos, 'R', c.R, 'readout', c.readout, ...
    'clockOffset', c.clockOffset, 'clockDrift', c.clockDrift, 'recordStart', c.recordStart), cams);
t.scenario = rmfield(sc, 'rallies');
tv.util.writeJson(fullfile(folder, 'truth.json'), t);
save(fullfile(folder, 'truth.mat'), 'truth', 'cams', 'sc');
end
