function R = calibStudy(outDir, opts)
%CALIBSTUDY  Tuesday's two camera views, calibrated from the court lines, against the true cameras (22 Nov, item 7).
%   R = calibStudy('out/calibstudy')
%   The 4K dress rehearsal put camera 2 5.5 m too far back along the court, with the line fit looking
%   good (99% of the lines on paint, 0.6 px), while at 960 x 540 both cameras were within 5 cm.
%   This renders each camera's empty-court picture (tv.synth.tuesdayClip clip 1, SYNTHETIC) at each
%   size in opts.sizes, optionally through HEVC as the camera files are, and runs tv.calib.searchPose
%   with each line setting in opts.settings:
%     'real'       tv.calib.lineOptsFor(width): what quickLook and the pipeline use on camera files
%     'synthetic'  tv.calib.lineOptsFor('synthetic'): the settings the tests use on clean pictures
%   For each: the found position and its distance from the truth, the line fit (rms, support), and
%   the best few candidates with their distance from the truth. Writes calibstudy.md.
if nargin < 1, outDir = fullfile(pwd, 'out', 'calibstudy'); end
if nargin < 2, opts = struct(); end
d = struct('sizes', {{'camera', 'small'}}, 'settings', {{'real', 'synthetic'}}, 'hevc', true, 'cams', [1 2]);
for f = fieldnames(d)', if ~isfield(opts, f{1}), opts.(f{1}) = d.(f{1}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
here = fileparts(mfilename('fullpath'));
M = tv.readJson(fullfile(here, '..', 'groundtruth', 'template.json'));
cfg = tv.pipeline.defaults();
lensCfg = tv.readJson(cfg.placementFile);
lens = tv.lens.build(lensCfg.lenses, 'Linear', cfg.aspect);
rows = struct('size', {}, 'cam', {}, 'setting', {}, 'truePos', {}, 'pos', {}, 'errM', {}, 'rmsPx', {}, 'support', {}, 'cand', {}, 'seconds', {});
for sz = opts.sizes
    [sc, truth] = tv.synth.tuesdayClip('clip1', M, sz{1});
    cams = tv.synth.cameras(sc);
    for k = opts.cams
        bg = tv.synth.renderBackground(cams(k), sc);
        img = double(tv.synth.renderFrame(cams(k), bg, sc, truth, 1, 1));
        if opts.hevc, img = hevcOnce(img, sc.crf); end
        L = tv.lens.atResolution(lens, size(img, 2), size(img, 1));
        for st = opts.settings
            if strcmp(st{1}, 'real'), lo = tv.calib.lineOptsFor(size(img, 2)); else, lo = tv.calib.lineOptsFor('synthetic'); end
            t0 = tic;
            try
                [cam, r0] = tv.calib.searchPose(img, L, struct('lineOpts', lo));
                cand = zeros(0, 2);
                if isfield(r0, 'candidates') && ~isempty(r0.candidates)
                    C = r0.candidates;  n = min(5, size(C, 1));      % [x y z inliers rmsPx cost support], in the search's order
                    cand = [C(1:n, end), sqrt(sum((C(1:n, 1:3) - cams(k).pos(:)') .^ 2, 2))];
                end
                rows(end+1) = struct('size', sz{1}, 'cam', k, 'setting', st{1}, 'truePos', cams(k).pos(:)', 'pos', cam.pos(:)', ...
                    'errM', norm(cam.pos(:) - cams(k).pos(:)), 'rmsPx', r0.rmsPx, 'support', r0.support, 'cand', cand, 'seconds', toc(t0)); %#ok<AGROW>
            catch err
                rows(end+1) = struct('size', sz{1}, 'cam', k, 'setting', st{1}, 'truePos', cams(k).pos(:)', 'pos', nan(1, 3), ...
                    'errM', NaN, 'rmsPx', NaN, 'support', NaN, 'cand', zeros(0, 2), 'seconds', toc(t0)); %#ok<AGROW>
                fprintf('%s camera %d %s: %s\n', sz{1}, k, st{1}, err.message);
            end
            x = rows(end);
            fprintf('%s camera %d %s: found %s, truth %s, %.2f m off, rms %.2f px, support %.3f (%.0f s)\n', x.size, k, x.setting, ...
                mat2str(x.pos, 4), mat2str(x.truePos, 4), x.errM, x.rmsPx, x.support, x.seconds);
        end
    end
end
R.rows = rows;
L = {'# Calibration from the court lines: Tuesday''s cameras against the truth (SYNTHETIC)', '', ...
    sprintf('tools/calibStudy.m: clip 1''s empty court, Linear lens, %s. Candidates: the best five poses the search kept, with their distance from the true camera.', ...
    tv.testing.ternary(opts.hevc, 'each picture coded once with HEVC as the camera files are', 'uncoded pictures')), '', ...
    '| Size | Camera | Line settings | Found (x, y, z), m | Truth, m | Off by, m | Line rms, px | Lines on paint | Candidates: off by, m | Time, s |', ...
    '|---|---|---|---|---|---|---|---|---|---|'};
for x = rows(:)'
    cs = strjoin(arrayfun(@(v) sprintf('%.2f', v), x.cand(:, end)', 'UniformOutput', false), ', ');
    L{end+1} = sprintf('| %s | %d | %s | %s | %s | %.2f | %.2f | %.1f%% | %s | %.0f |', x.size, x.cam, x.setting, mat2str(x.pos, 4), ...
        mat2str(x.truePos, 4), x.errM, x.rmsPx, 100 * x.support, cs, x.seconds); %#ok<AGROW>
end
fid = fopen(fullfile(outDir, 'calibstudy.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
end

function img = hevcOnce(img, crf)
% one picture through libx265 as tv.synth.writeRecording codes the camera files
d = tempname();  mkdir(d);  a = fullfile(d, 'a.png');  b = fullfile(d, 'b.mp4');  c = fullfile(d, 'c.png');
imwrite(uint8(img), a);
tv.util.run(sprintf('%s -y -v error -i "%s" -c:v libx265 -preset ultrafast -crf %d -x265-params log-level=error -pix_fmt yuv420p "%s"', tv.util.ffmpeg(), a, crf, b));
tv.util.run(sprintf('%s -y -v error -i "%s" -frames:v 1 "%s"', tv.util.ffmpeg(), b, c));
img = double(imread(c));
rmdir(d, 's');
end
