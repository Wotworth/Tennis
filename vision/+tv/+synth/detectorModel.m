function M = detectorModel(csvFile, name)
%DETECTORMODEL  A ball detector's measured behaviour by ball size, for the fit study (SYNTHETIC).
%   M = tv.synth.detectorModel('out/sizestudy/sizestudy.csv', 'learned')
%   Reads the table written by tools/detectorSizeStudy.m and returns, per ball diameter M.d (px):
%   M.recall, the share of frames in which the tracker is given a spot on the ball (score over
%   0.05), and M.sigma, the centre error per axis (px: the measured rms over both axes divided by
%   the square root of 2). tv.synth.observe uses it in place of its flat 0.5 px and 5% misses.
fid = fopen(csvFile, 'r');
if fid < 0, error('tv:synth:model', 'Cannot read %s', csvFile); end
fgetl(fid);
M = struct('name', name, 'd', [], 'recall', [], 'sigma', []);
while true
    l = fgetl(fid);
    if ~ischar(l), break; end
    f = strsplit(l, ',');
    if ~strcmp(f{1}, name), continue; end
    v = str2double(f(2:end));          % d, proposed, found05, found5, errMedian, errRms, err90, along
    M.d(end+1) = v(1);  M.recall(end+1) = v(3);  M.sigma(end+1) = v(6) / sqrt(2);
end
fclose(fid);
if isempty(M.d), error('tv:synth:model', 'No rows for detector %s in %s', name, csvFile); end
M.sigma(~isfinite(M.sigma)) = max(M.sigma(isfinite(M.sigma)));
end
