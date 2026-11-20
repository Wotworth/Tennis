function shotStudy(outDir, opts)
%SHOTSTUDY  Hundreds of synthetic shots with Tuesday's set-up, one run per ball detector (Chris, 20 Nov).
%   shotStudy('out/shotstudy')
%   1. tools/detectorSizeStudy.m measures each detector's recall and centre error by ball size.
%   2. tools/fitStudy.m flies the same session for each detector (same shots, same seed): Linear
%      lens, 4K at 240 frames a second, cameras at the TV-PH-0a positions, sidespin on, and a
%      third of the rallies started by a ball machine on four settings. Its observations come
%      from that detector's measured behaviour at the size the ball really is in each frame.
%   Answers: does the detector change speed accuracy (item 5), how well is sideways curve
%   measured (item 14), and bounce, speed and spin-effect errors for Tuesday's set-up (item 22).
%   opts.gustAmp 0 runs it in calm air (only a steady wind), to see what the gusts cost.
%   Writes sizestudy.md, fitstudy_<detector>.md and shotstudy.md (the comparison).
if nargin < 1, outDir = fullfile(pwd, 'out', 'shotstudy'); end
if nargin < 2, opts = struct(); end
d = struct('targetShots', 300, 'minutes', 75, 'detectors', {{'learned', 'learnedRaw', 'colour'}}, 'trials', 150, 'gustAmp', 0.6, 'liftModel', 'constant');
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
detectorSizeStudy(outDir, struct('trials', opts.trials));
csv = fullfile(outDir, 'sizestudy.csv');
rows = {};
for i = 1:numel(opts.detectors)
    name = opts.detectors{i};
    M = tv.synth.detectorModel(csv, name);
    R = fitStudy(outDir, struct('scenario', 'tuesday', 'errModel', M, 'sideSpin', true, 'machine', 0.33, ...
        'targetShots', opts.targetShots, 'minutes', opts.minutes, 'gustAmp', opts.gustAmp, 'liftModel', opts.liftModel, 'tag', [name tv.testing.ternary(opts.gustAmp == 0, '_calm', '') '_' opts.liftModel], ...
        'title', sprintf('Tuesday set-up, detector: %s%s, lift %s', name, tv.testing.ternary(opts.gustAmp == 0, ', calm air', ''), opts.liftModel)));
    r = R.rows;  f = [r.found];
    sp = abs([r.speedErr]) * 2.23694;  sp = sp(isfinite(sp));
    cv = abs([r.curveErr]) * 100;  cv = cv(isfinite(cv));
    rows(end+1, :) = {[name tv.testing.ternary(opts.gustAmp == 0, ' (calm)', '') ', lift ' opts.liftModel], nnz(f), numel(f), mean(sp < 2), median(sp), p90(sp), median([r(isfinite([r.bounceErr])).bounceErr]) * 100, ...
        median(abs([r(isfinite([r.spinErr])).spinErr])) * 100, median(cv), p90(cv), R.farBallPx}; %#ok<AGROW>
end
L = {'# Shot study: the ball detectors on Tuesday''s set-up (SYNTHETIC)', ''};
L{end+1} = sprintf('The same %d-shot session for each detector: Linear lens, 4K, 240 frames a second, the far-corner ball %.1f px across, sidespin, a third of the rallies fed by a ball machine. Details: fitstudy_<detector>.md; the detectors by ball size: sizestudy.md.', opts.targetShots, rows{1, end});
L{end+1} = '';
L{end+1} = '| Detector | Shots found | Speed within 2 mph | Speed error median / 90th, mph | Bounce error median, cm | Spin effect error median, cm | Sideways curve error median / 90th, cm |';
L{end+1} = '|---|---|---|---|---|---|---|';
for i = 1:size(rows, 1)
    r = rows(i, :);
    L{end+1} = sprintf('| %s | %d of %d | %.0f%% | %.2f / %.2f | %.1f | %.1f | %.1f / %.1f |', r{1}, r{2}, r{3}, 100 * r{4}, r{5}, r{6}, r{7}, r{8}, r{9}, r{10}); %#ok<AGROW>
end
fid = fopen(fullfile(outDir, 'shotstudy.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
end

function v = p90(x)
x = sort(x(isfinite(x)));
if isempty(x), v = NaN; return; end
v = x(max(1, ceil(0.9 * numel(x))));
end
