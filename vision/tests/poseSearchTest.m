% tv.calib.searchPose (TV-CAL-10, 11): each synthetic camera's pose from the court lines alone, with
% no layout assumed, for the Wide and the Linear lens. The pose must be the true one (or its
% half-turn twin, which the second camera resolves later), not a look-alike: a court moved one
% doubles alley sideways puts most lines on other lines and matched many points on the first
% real pictures (19 Nov); line-by-line support tells them apart.
if exist('OCTAVE_VERSION', 'builtin'), pkg load image; pkg load optim; pkg load statistics; end

%% Wide lens: both cameras within 0.1 m, every near-half line with paint under it
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
for k = 1:2
    bg = tv.synth.renderBackground(cams(k), sc);
    [cam, rep] = tv.calib.searchPose(bg, cams(k).lens);
    tw = tv.calib.rotate180(cam);
    off = min(norm(cam.pos - cams(k).pos), norm(tw.pos - cams(k).pos));
    assert(off < 0.1, sprintf('camera %d is %.2f m from the truth', k, off));
    assert(rep.support > 0.9, sprintf('camera %d: line support %.2f', k, rep.support));
    assert(rep.rmsPx < 1, sprintf('camera %d: line error %.2f px', k, rep.rmsPx));
end

%% Linear lens (Chris, 19 Nov: the GoPros will record in Linear mode): the same
sc = tv.synth.defaultScenario();
sc.lensName = 'Linear';
cams = tv.synth.cameras(sc);
for k = 1:2
    bg = tv.synth.renderBackground(cams(k), sc);
    [cam, rep] = tv.calib.searchPose(bg, cams(k).lens);
    tw = tv.calib.rotate180(cam);
    off = min(norm(cam.pos - cams(k).pos), norm(tw.pos - cams(k).pos));
    assert(off < 0.1, sprintf('camera %d is %.2f m from the truth', k, off));
    assert(rep.support > 0.9, sprintf('camera %d: line support %.2f', k, rep.support));
    assert(rep.rmsPx < 1, sprintf('camera %d: line error %.2f px', k, rep.rmsPx));
end
