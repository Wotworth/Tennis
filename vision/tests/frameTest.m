% Court frame from where the cameras are, not from their serials (TV-ARCH-10, Chris 16 Nov).
% Two synthetic cameras see one ball flight; tv.calib.resolveSymmetry gets each
% camera's pose with or without its half-turn twin, in either camera order,
% and must return the true poses: cameras on the y < 0 side, proper rotations
% (a right-handed frame), whichever camera is called "1".
sc = tv.synth.defaultScenario();
truth = tv.synth.cameras(sc);
prm = tv.physics.defaultParams();
[tt, P] = tv.physics.simulate([-10, 1, 1.0], [24, -1.5, 4], prm, 1.0);
fps = 120;  f = (0:floor(tt(end) * fps))';
B = interp1(tt, P, f / fps);
sync0 = struct('startOffset', [0 0], 'delta', 0, 'drift', 0, 'tref', 0, 'readout', [0 0], 'shutter', 0);
%% Cameras in the usual order: the twin of either pose is undone
[tracks, rec] = tv.testing.flightTracks(truth, B, f, fps);
for tw = [0 0; 1 0; 0 1; 1 1]'
    cands = truth;
    for k = find(tw'), cands(k) = tv.calib.rotate180(cands(k)); end
    [cams, rep] = tv.calib.resolveSymmetry(cands, tracks, rec, sync0, []);
    tv.testing.samePoses(cams, truth);
    assert(~rep.cam2AtLowerX)
end

%% Cameras swapped (mounted at the other ends): same right-handed frame, x does not follow the serials
swapped = truth([2 1]);
[tracks, rec] = tv.testing.flightTracks(swapped, B, f, fps);
for tw = [0 0; 1 0; 0 1; 1 1]'
    cands = swapped;
    for k = find(tw'), cands(k) = tv.calib.rotate180(cands(k)); end
    [cams, rep] = tv.calib.resolveSymmetry(cands, tracks, rec, sync0, []);
    tv.testing.samePoses(cams, swapped);
    assert(rep.cam2AtLowerX)       % reported, so outputs can say which camera is at which end
end
