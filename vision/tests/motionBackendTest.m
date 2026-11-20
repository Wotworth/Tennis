if exist('OCTAVE_VERSION', 'builtin'), pkg load image; end
% Spot-finding on the graphics card (Chris, 22 Nov, item 8): the whole-frame array backend, which runs
% as gpuArray on the PC's graphics card, finds exactly the spots the CPU loop finds. Here (no
% graphics card) the array code runs on the processor: the same operations, the same numbers.

%% The array backend and the CPU loop give identical spots on synthetic footage
sc = tv.synth.defaultScenario();  cams = tv.synth.cameras(sc);
truth = tv.synth.planSession(sc);
bg = tv.synth.renderBackground(cams(1), sc);
S = tv.detect.ballSizeMap(cams(1), tv.court.interest());
S.dmin = S.dmin * sc.ballDrawScale;  S.dmax = S.dmax * sc.ballDrawScale;
K = 4;  n = 0;
for f = [300 480 620 2400]                                % frames with the ball in flight
    fr = arrayfun(@(i) tv.synth.renderFrame(cams(1), bg, sc, truth, i, 7), f + (-K:K:K), 'UniformOutput', false);
    [C1, t1] = tv.detect.motionProposals(fr{1}, fr{2}, fr{3}, S, struct('backend', 'cpu'));
    [C2, t2] = tv.detect.motionProposals(fr{1}, fr{2}, fr{3}, S, struct('backend', 'array'));
    assert(isequal(t1, t2))
    assert(isequal(size(C1), size(C2)) && isequal(C1, C2), sprintf('frame %d: %d spots against %d', f, size(C1, 1), size(C2, 1)))
    n = n + size(C1, 1);
end
fprintf('%d spots, identical in both backends\n', n);
assert(n > 0)
