% Court corners a camera sees (TV-CAL-20, Chris 17 Nov): a camera that sees the whole court
% gives no warning; one aimed so the near right corners fall outside names them.
sc = tv.synth.defaultScenario();
cams = tv.synth.cameras(sc);
c = tv.court.constants();

%% The planned cameras see all eight corners: no warning
for k = 1:numel(cams)
    rep = tv.calib.corners(cams(k));
    assert(all(rep.seen), strjoin(rep.missing', ', '))
    assert(isempty(rep.text))
end

%% A low camera behind one baseline, turned left, misses its near right corners and says so
lens = cams(1).lens;
cam = tv.camera.make(lens, [-c.halfLength - 2, 0, 1.5], 22, -8, 0);
rep = tv.calib.corners(cam);
assert(~all(rep.seen))
assert(all(strncmp(rep.missing, 'near right', 10)), strjoin(rep.missing', ', '))
assert(~isempty(strfind(rep.text, 'near right doubles')))
