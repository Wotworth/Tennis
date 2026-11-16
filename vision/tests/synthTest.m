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

%% Every shot that was meant to land, lands near its target, but not exactly
% (aimed with the fitter's model, flown with the truth model: the two must differ)
miss = [];
for s = truth.shots'
    if strcmp(s.result, 'net'), continue; end
    target = sc.rallies(s.rally).shots{s.index, 1};
    miss(end+1) = norm(s.pBounce(1:2) - target); %#ok<AGROW>
end
assert(all(miss < 1.5))          % 0.07-1.02 m on 16 Nov
assert(max(miss) > 0.03)

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

%% The exact synthetic timing (tv.synth.truthSync) maps a detection to its true moment
cams0 = tv.synth.cameras(sc);
S2 = tv.synth.studySession(3, struct('minutes', 2, 'targetShots', 3));
O2 = tv.synth.observe(S2, cams0, struct('sigmaPx', 0, 'dropout', 0, 'posErrM', 0, 'rotErrDeg', 0));
sy = tv.synth.truthSync(cams0, O2.sync0);
tr = O2.tracks{1, 2};  n = tr.frames(20);  v = tr.uv(20, 2);
tP = tv.recon.detTimes(2, n, v, O2.rec, sy);
tT = tv.synth.truthTime(cams0(2), cams0(2).recordStart + O2.rec(2).pts(n + 1)) + cams0(2).readout * (v - 1) / cams0(2).height + sy.shutter / 2;
assert(abs(tP - tT) < 1e-6)
