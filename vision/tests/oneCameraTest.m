% tv.recon.segments with one camera blocked (Chris, 18 Nov): a flight only one camera sees is
% still found, from that camera's sight lines, the physics and where the flights either
% side of it end or begin (TV-REC-01). A rally of three flights: hit, bounce, hit, then a
% reply. SYNTHETIC: two 4K cameras, 0.5 px detector noise, no timing or pose errors.
if exist('OCTAVE_VERSION', 'builtin'), pkg load optim; end
sc = tv.synth.defaultScenario();  sc.frameSize = [3840 2160];
cams = tv.synth.cameras(sc);
air = tv.physics.defaultParams();
c = tv.court.constants();
prior = struct('CD', 0.507, 'CDsd', 0.024);
% truth: a topspin drive from the near baseline, its bounce, the rise to the next hit, the reply
prm = air;  prm.CL = 0.2;  prm.spinAxis = [0 1 0];
[tA, PA, VA] = tv.physics.simulate([-11.5 1.0 0.9], [24 -2.2 5.2], prm, 3, 1e-3, c.ballRadius);
[pB, tBounce] = tv.physics.groundHit(PA, tA);
iB = find(tA <= tBounce, 1, 'last');
prmB = air;  prmB.CL = 0.04;
[tB, PB] = tv.physics.simulate([pB(1:2), c.ballRadius + 1e-4], tv.physics.bounce(VA(iB, :), air), prmB, 0.55);
prmC = air;  prmC.CL = 0.1;  prmC.spinAxis = [0 -1 0];
[tC, PC] = tv.physics.simulate(PB(end, :), [-22 1.5 4.5], prmC, 0.6);
T0 = 2.0;                                     % the first hit, session time
flights = {T0 + tA(1:iB), PA(1:iB, :); T0 + tBounce + tB, PB; T0 + tBounce + tB(end) + tC, PC};
tHit2 = T0 + tBounce + tB(end);
truth = struct('bounce', pB, 'tBounce', T0 + tBounce, 'hit2', PB(end, :), 'tHit2', tHit2);
fps = 120;
% what each camera's detector reports, with camera 2 blind between two session times; the flights and events found
run = @(blind, opts) tv.testing.runRally(cams, flights, fps, blind, air, prior, opts);
% what was found, for the log; and how far the nearest bounce and hit found are from the truth
show = @(name, segs, ev) fprintf('%s: flights %s; events %s\n', name, ...
    strjoin(arrayfun(@(g) sprintf('%.3f-%.3f (%d/%d, %.2f px%s)', min(g.t), max(g.t), g.n(1), g.n(2), g.rmsPx, tv.testing.ternary(g.oneCam, ', one camera', '')), segs(:)', 'UniformOutput', false), ', '), ...
    strjoin(arrayfun(@(e) sprintf('%s %.3f (%.2f %.2f %.2f)', e.type, e.t, e.p), ev(:)', 'UniformOutput', false), ', '));
kind = @(ev, type) ev(strcmp({ev.type}, type));
offM = @(ev, type, p) min([Inf, arrayfun(@(e) norm(e.p(1:numel(p)) - p), kind(ev, type))]);
fprintf('truth: hit %.3f, bounce %.3f at (%.2f %.2f), hit %.3f at (%.2f %.2f %.2f), ends %.3f\n', T0, truth.tBounce, truth.bounce(1:2), truth.tHit2, truth.hit2, flights{3, 1}(end));

%% both cameras throughout: three flights, bounce within 3 cm
segs = run(zeros(0, 3), struct());
ev = tv.events.classify(segs, air);
show('both cameras', segs, ev);
assert(numel(segs) == 3 && ~any([segs.oneCam]), sprintf('%d flights', numel(segs)));
assert(numel(kind(ev, 'bounce')) == 1 && offM(ev, 'bounce', truth.bounce(1:2)) < 0.03, sprintf('%d bounces, the nearest %.3f m off', numel(kind(ev, 'bounce')), offM(ev, 'bounce', truth.bounce(1:2))));

%% camera 2 blind from the bounce to the next hit: without the one-camera step that flight is lost
blind = [2, truth.tBounce - 0.002, truth.tHit2 + 0.002];
old = run(blind, struct('oneCam', false));
show('blind after the bounce, old', old, tv.events.classify(old, air));
segs = run(blind, struct());
ev = tv.events.classify(segs, air);
show('blind after the bounce', segs, ev);
assert(numel(old) == 2, sprintf('%d flights without the one-camera step', numel(old)));
assert(numel(segs) == 3 && isequal([segs.oneCam], [false true false]), sprintf('%d flights, one-camera %s', numel(segs), mat2str([segs.oneCam])));
assert(numel(kind(ev, 'bounce')) == 1 && offM(ev, 'bounce', truth.bounce(1:2)) < 0.05, sprintf('%d bounces, the nearest %.3f m off', numel(kind(ev, 'bounce')), offM(ev, 'bounce', truth.bounce(1:2))));
h = kind(ev, 'hit');
assert(numel(h) == 1 && abs(h.t - truth.tHit2) < 0.015 && norm(h.p - truth.hit2) < 0.25, sprintf('%d hits, the nearest %.2f m off', numel(h), offM(ev, 'hit', truth.hit2)));

%% camera 2 blind for the whole flight to the bounce: found from camera 1 and the ground
blind = [2, 0, truth.tBounce + 0.002];
segs = run(blind, struct());
ev = tv.events.classify(segs, air);
show('blind before the bounce', segs, ev);
assert(numel(segs) == 3 && isequal([segs.oneCam], [true false false]), sprintf('%d flights, one-camera %s', numel(segs), mat2str([segs.oneCam])));
assert(numel(kind(ev, 'bounce')) == 1 && offM(ev, 'bounce', truth.bounce(1:2)) < 0.10, sprintf('%d bounces, the nearest %.3f m off', numel(kind(ev, 'bounce')), offM(ev, 'bounce', truth.bounce(1:2))));
[~, V0] = tv.recon.segmentModel(segs(1).x, segs(1).t0, T0 + 0.05, air);
fprintf('blind before the bounce: speed after the hit %.2f m/s off (truth %.1f)\n', norm(V0) - norm(VA(51, :)), norm(VA(51, :)));
assert(abs(norm(V0) - norm(VA(51, :))) < 1.5, sprintf('speed %.2f m/s off', norm(V0) - norm(VA(51, :))));

%% camera 2 blind for the middle half of the first flight: one flight still, bounce within 3 cm
blind = [2, T0 + tBounce * [0.25 0.75]];
segs = run(blind, struct());
ev = tv.events.classify(segs, air);
show('blind mid-flight', segs, ev);
assert(numel(segs) == 3 && ~any([segs.oneCam]), sprintf('%d flights', numel(segs)));
assert(segs(1).n(1) > segs(1).n(2) + 20, 'camera 1''s detections in the gap were not used');
assert(numel(kind(ev, 'bounce')) == 1 && offM(ev, 'bounce', truth.bounce(1:2)) < 0.03, sprintf('%d bounces, the nearest %.3f m off', numel(kind(ev, 'bounce')), offM(ev, 'bounce', truth.bounce(1:2))));
