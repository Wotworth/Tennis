function samePoses(got, want)
%SAMEPOSES  Assert two camera pairs match, as proper rotations on the y < 0 side (tests, TV-ARCH-10).
for k = 1:2
    assert(norm(got(k).pos - want(k).pos) < 1e-6, 'camera %d in the wrong place', k)
    assert(norm(got(k).R - want(k).R) < 1e-6, 'camera %d turned', k)
    assert(abs(det(got(k).R) - 1) < 1e-9, 'not a rotation: the frame would be left-handed')
    assert(got(k).pos(2) < 0, 'cameras must be on the y < 0 side')
end
end
