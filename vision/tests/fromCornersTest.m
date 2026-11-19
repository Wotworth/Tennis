% tv.calib.fromCorners (TV-CAL-11 fallback; Chris, 19 Nov): a camera's pose from the four corners
% of the doubles court tapped on its picture, in any order, a finger's width off; then sharpened
% on the court's lines without being pulled onto the wrong ones.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; pkg load optim; pkg load statistics; end
c = tv.court.constants();
X = [-c.halfLength -c.halfDoubles 0; -c.halfLength c.halfDoubles 0; c.halfLength c.halfDoubles 0; c.halfLength -c.halfDoubles 0];

%% Wide lens, both cameras: taps up to 6 px off, in any order, give the pose within 0.1 m once the lines refine it
tv.util.seed(4);
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
for k = 1:2
    bg = tv.synth.renderBackground(cams(k), sc);
    [px, ok] = tv.camera.project(cams(k), X);
    assert(all(ok) && all(px(:, 1) > 1 & px(:, 1) < cams(k).width & px(:, 2) > 1 & px(:, 2) < cams(k).height), 'a corner is out of this camera''s picture');
    taps = px(randperm(4), :) + 6 * (2 * rand(4, 2) - 1);
    [cam, rep] = tv.calib.fromCorners(bg, cams(k).lens, taps, struct('lineOpts', tv.calib.lineOptsFor('synthetic')));
    tw = tv.calib.rotate180(cam);
    off = min(norm(cam.pos - cams(k).pos), norm(tw.pos - cams(k).pos));
    assert(off < 0.1, sprintf('camera %d is %.2f m from the truth', k, off));
    assert(rep.refined && rep.support > 0.9, sprintf('camera %d: refined %d, support %.2f', k, rep.refined, rep.support));
    assert(rep.tapRmsPx < 8, sprintf('camera %d: corners %.1f px from the taps', k, rep.tapRmsPx));
    assert(cam.pos(2) <= 0, 'the twin on the y <= 0 side is the one returned');
end

%% Linear lens: the same
tv.util.seed(5);
sc = tv.synth.defaultScenario();
sc.lensName = 'Linear';
sc.mountX = c.halfLength + 2.5;                        % Linear's spot for a fence 4 m out (docs/reports/TV-PH-0a.md): 2.5 m behind each baseline
cams = tv.synth.cameras(sc);
for k = 1:2
    bg = tv.synth.renderBackground(cams(k), sc);
    [px, ok] = tv.camera.project(cams(k), X);
    assert(all(ok) && all(px(:, 1) > 1 & px(:, 1) < cams(k).width & px(:, 2) > 1 & px(:, 2) < cams(k).height), 'a corner is out of this camera''s picture');
    taps = px(randperm(4), :) + 6 * (2 * rand(4, 2) - 1);
    [cam, rep] = tv.calib.fromCorners(bg, cams(k).lens, taps, struct('lineOpts', tv.calib.lineOptsFor('synthetic')));
    tw = tv.calib.rotate180(cam);
    off = min(norm(cam.pos - cams(k).pos), norm(tw.pos - cams(k).pos));
    assert(off < 0.1, sprintf('camera %d is %.2f m from the truth', k, off));
    assert(rep.support > 0.9, sprintf('camera %d: support %.2f', k, rep.support));
end

%% No lines to help (a blank picture): the tapped pose stands, and exact taps give the exact pose
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
blank = 90 * ones(cams(1).height, cams(1).width, 3);
px = tv.camera.project(cams(1), X);
[cam, rep] = tv.calib.fromCorners(blank, cams(1).lens, px([3 1 4 2], :));
tw = tv.calib.rotate180(cam);
assert(min(norm(cam.pos - cams(1).pos), norm(tw.pos - cams(1).pos)) < 0.01);
assert(~rep.refined && rep.tapRmsPx < 0.05);
% and with a finger's error the tapped pose alone is within a metre
tv.util.seed(6);
[cam, rep] = tv.calib.fromCorners(blank, cams(1).lens, px + 6 * (2 * rand(4, 2) - 1));
tw = tv.calib.rotate180(cam);
assert(min(norm(cam.pos - cams(1).pos), norm(tw.pos - cams(1).pos)) < 1.0);

%% Three taps are refused
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
px = tv.camera.project(cams(1), X);
ok = false;
try, tv.calib.fromCorners(90 * ones(cams(1).height, cams(1).width, 3), cams(1).lens, px(1:3, :)); catch err, ok = strcmp(err.identifier, 'tv:calib:corners'); end
assert(ok);
