% Synthetic footage generator (TV-TST-01): the truth it writes is what it renders.
sc = tv.synth.defaultScenario();
persistentTruth = fullfile(tempdir, 'tv_synth_truth.mat');
if exist(persistentTruth, 'file')
    S = load(persistentTruth);  truth = S.truth;
else
    truth = tv.synth.planSession(sc);  save(persistentTruth, 'truth');
end
cams = tv.synth.cameras(sc);
c = tv.court.constants();

%% Every shot that was meant to land, lands within 1 cm of its target
for s = truth.shots'
    if strcmp(s.result, 'net'), continue; end
    target = sc.rallies(s.rally).shots{s.index, 1};
    assert(norm(s.pBounce(1:2) - target) < 0.01, 'rally %d shot %d', s.rally, s.index)
end

%% Rally 1 ends with a ball out long, rally 2 with a ball in the net
r1 = truth.shots([truth.shots.rally] == 1);  r2 = truth.shots([truth.shots.rally] == 2);
assert(strcmp(r1(end).result, 'out') && r1(end).pBounce(1) > c.halfLength)
assert(strcmp(r2(end).result, 'net'))

%% Topspin lands shorter than the same launch with no spin, slice longer
for s = truth.shots'
    if s.CL == 0 || strcmp(s.result, 'net'), continue; end
    push = cross(s.spinAxis, s.vHit / norm(s.vHit));
    assert(sign(s.spinEffect) == sign(push(3)), 'rally %d shot %d', s.rally, s.index)
end

%% The drawn ball sits where the camera model says, row timing included
cam = cams(1);
bg = zeros(cam.height, cam.width, 3);
sc0 = sc;  sc0.noiseSigma = 0;  sc0.flicker = 0;  sc0.staticBall = [100 100 0];   % static ball out of view
s = truth.shots(3);
n = round((s.tHit + 0.25 - cam.recordStart) * cam.fps);
img = double(tv.synth.renderFrame(cam, bg, sc0, truth, n, 1));
yellow = img(:,:,1) > 100 & img(:,:,2) > 100 & img(:,:,3) < 100;
[r, q] = find(yellow);
got = [mean(q), mean(r)];
% where the model puts it, at the time its row was exposed
clock = cam.recordStart + n / cam.fps;
v = got(2);
P = tv.synth.ballAt(truth, tv.synth.truthTime(cam, clock + cam.readout * (v - 1) / cam.height + cam.shutter / 2));
want = tv.camera.project(cam, P);
assert(norm(got - want) < 1.0)

%% Each hit is heard in each camera's sound after the sound's travel time
[y, fs] = tv.synth.renderAudio(cams(2), sc, truth);
s = truth.shots(2);
Tarr = s.tHit + norm(s.pHit - cams(2).pos) / tv.air.speedOfSound(sc.weather.tempC);
i0 = round(((Tarr - cams(2).clockOffset) / (1 + cams(2).clockDrift) - cams(2).recordStart) * fs) + 1;
before = max(abs(y(i0 - 200:i0 - 5)));  after = max(abs(y(i0:i0 + 100)));
assert(after > 5 * before)
