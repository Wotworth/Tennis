function R = cornerTapStudy(outDir, opts)
%CORNERTAPSTUDY  Does tap accuracy matter? Camera pose from four tapped corners, by tap error (Chris, 20 Nov).
%   R = cornerTapStudy('out/cornertaps')
%   For each synthetic camera set-up (opts.setups: 'wide' = the test generator's cameras; 'linear'
%   = Tuesday's Linear-mode positions), each tap error in opts.errPx (px at 1920 wide, scaled to
%   the picture) and opts.trials random directions: tv.calib.fromCorners places the camera from the
%   four taps and then sharpens the pose on all the court's lines (within 0.7 m and 2 degrees).
%   Reported: how far the camera ends up from the truth, the corners' distance from the true
%   corners in the picture, the share of the fitted lines with paint under them, and how often the
%   line refinement was kept. Writes cornertaps.md.
if nargin < 1, outDir = fullfile(pwd, 'out', 'cornertaps'); end
if nargin < 2, opts = struct(); end
d = struct('setups', {{'wide', 'linear'}}, 'errPx', [0 3 6 12 25 50], 'trials', 6, 'seed', 9, 'width', 1920);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
c = tv.court.constants();
X = [-c.halfLength -c.halfDoubles 0; -c.halfLength c.halfDoubles 0; c.halfLength c.halfDoubles 0; c.halfLength -c.halfDoubles 0];
rows = {};
for s = opts.setups
    sc = tv.synth.defaultScenario();  sc.frameSize = [opts.width, round(opts.width * 9 / 16)];
    if strcmp(s{1}, 'linear'), sc.lensName = 'Linear';  sc.mountX = c.halfLength + 2.5; end
    cams = tv.synth.cameras(sc);  cam = cams(1);
    bg = tv.synth.renderBackground(cam, sc);
    lo = tv.calib.lineOptsFor('synthetic');
    [mask, ~] = tv.calib.linePixels(bg, lo);
    supTrue = tv.calib.lineSupport(cam, mask);
    px = tv.camera.project(cam, X);
    tv.util.seed(opts.seed);
    for e = opts.errPx
        pos = [];  cor = [];  sup = [];  ref = [];
        for t = 1:opts.trials
            a = 2 * pi * rand(4, 1);
            taps = px + e * [cos(a), sin(a)] * (sc.frameSize(1) / 1920);
            try
                [cf, rep] = tv.calib.fromCorners(bg, cam.lens, taps(randperm(4), :), struct('lineOpts', lo));
            catch
                continue
            end
            tw = tv.calib.rotate180(cf);
            pos(end+1) = min(norm(cf.pos - cam.pos), norm(tw.pos - cam.pos)); %#ok<AGROW>
            q = tv.camera.project(cf, X);  if norm(cf.pos - cam.pos) > norm(tw.pos - cam.pos), q = tv.camera.project(tw, X); end
            cor(end+1) = sqrt(mean(sum((q - px) .^ 2, 2))); %#ok<AGROW>
            sup(end+1) = rep.support;  ref(end+1) = rep.refined; %#ok<AGROW>
        end
        rows(end+1, :) = {s{1}, e, numel(pos), median(pos), max(pos), median(cor), median(sup), mean(ref), supTrue}; %#ok<AGROW>
        fprintf('%s, taps %g px off: camera %.3f m (worst %.3f), corners %.2f px, support %.2f (truth %.2f), refined %.0f%%\n', ...
            s{1}, e, median(pos), max(pos), median(cor), median(sup), supTrue, 100 * mean(ref));
    end
end
L = {'# Four tapped corners: does tap accuracy matter? (SYNTHETIC)', ''};
L{end+1} = sprintf('Camera 1 of the synthetic set-ups, picture %d px wide; each tap moved a fixed distance in a random direction (%d trials each). The pose from the taps is sharpened on all the court''s lines (tv.calib.fromCorners).', opts.width, opts.trials);
L{end+1} = '';
L{end+1} = '| Set-up | Tap error (px at 1920 wide) | Camera from the truth, median (worst), cm | Corners from the true corners, px | Lines with paint under them | Line refinement kept |';
L{end+1} = '|---|---|---|---|---|---|';
for i = 1:size(rows, 1)
    r = rows(i, :);
    L{end+1} = sprintf('| %s | %g | %.1f (%.1f) | %.2f | %.0f%% (truth %.0f%%) | %.0f%% |', r{1}, r{2}, 100 * r{4}, 100 * r{5}, r{6}, 100 * r{7}, 100 * r{9}, 100 * r{8}); %#ok<AGROW>
end
fid = fopen(fullfile(outDir, 'cornertaps.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
R.rows = rows;
end
