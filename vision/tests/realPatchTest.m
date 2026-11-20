% Realistic patches for the size study (Chris, 22 Nov, item 12): every condition draws, the ball
% survives HEVC at the calibrated quantiser, occluders cover it, and the fit study reads the
% near-contact rows.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end

%% Every condition gives the frames asked for, coded
conds = {'clear', 'ballShadow', 'playerShadow', 'strings', 'bodyFront', 'bodyBehind'};
for i = 1:numel(conds)
    tv.util.seed(i);
    [F, bg, info] = tv.synth.realPatch(conds{i}, 4, [60 60], [5 2], [205 230 40], [-8 -1 0 1 8], struct('patch', 120));
    assert(isequal(size(F), [120 120 3 5]) && isequal(size(bg), [120 120 3]), conds{i})
    assert(info.bpp > 0.01 && info.bpp < 1, sprintf('%s: %.3f bits per pixel', conds{i}, info.bpp))
end

%% A 3 px ball on a clear court keeps its contrast through HEVC at quantiser 23
tv.util.seed(31);
[F, bg] = tv.synth.realPatch('clear', 3, [60 60], [6 3], [205 230 40], 0, struct('patch', 120));
dd = sum(abs(double(F(55:65, 55:65, :)) - double(bg(55:65, 55:65, :))), 3);
fprintf('3 px ball contrast after coding: %.0f\n', max(dd(:)));
assert(max(dd(:)) > 150)

%% Uncoded, the rolling shutter leans a ball moving sideways by its row time only
tv.util.seed(2);
[A] = tv.synth.realPatch('clear', 6, [60 60], [8 0], [205 230 40], 0, struct('patch', 120, 'codec', 'none', 'readNoise', 0, 'shotGain', 0));
tv.util.seed(2);
[B] = tv.synth.realPatch('clear', 6, [60 60], [8 0], [205 230 40], 0, struct('patch', 120, 'codec', 'none', 'readNoise', 0, 'shotGain', 0, 'readout', 0));
assert(max(abs(double(A(:)) - double(B(:)))) < 30)    % 8 ms over 2160 rows: a few hundredths of a pixel

%% The detector model reads the near-contact rows
f = [tempname() '.csv'];  fid = fopen(f, 'w');
fprintf(fid, 'detector,d,proposed,found05,found5,errMedian,errRms,err90,along\n');
fprintf(fid, 'learned,3,0.9,0.8,0.7,0.3,0.4,0.6,0\nlearned@hit,3,0.3,0.2,0.1,0.5,0.7,1.0,0\n');
fprintf(fid, 'learned,6,1,1,1,0.1,0.2,0.3,0\nlearned@hit,6,0.5,0.4,0.3,NaN,NaN,NaN,0\n');
fclose(fid);
M = tv.synth.detectorModel(f, 'learned');
assert(isequal(M.recall, [0.8 1]) && isfield(M, 'hit') && isequal(M.hit.recall, [0.2 0.4]))
assert(all(isfinite(M.hit.sigma)))
delete(f);
