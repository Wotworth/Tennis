% Provisional lens models from GoPro's published MISSION 1 angles (TV-CAL-04).
% Shared by every section (in matlab.unittest each section sees only this part)
cfg = tv.readJson(fullfile(fileparts(mfilename('fullpath')), '..', 'config', 'placement.json'));
W   = tv.lens.build(cfg.lenses, 'Wide', '16:9');
cam = tv.placement.pose([0 0 3], 90, -10);

%% Linear 16:9 puts the published horizontal half-angle on the frame edge
L = tv.lens.build(cfg.lenses, 'Linear', '16:9');
assert(abs(rad2deg(tv.lens.angleAt(L, 1)) - 50) < 1e-6)

%% Linear is rectilinear: the published vertical and diagonal angles follow
for a = {'16:9', '4:3'}
    L = tv.lens.build(cfg.lenses, 'Linear', a{1});
    e = cfg.lenses(arrayfun(@(x) strcmp(x.name, 'Linear') && strcmp(x.aspect, a{1}), cfg.lenses));
    ar = L.heightPx / L.widthPx;
    assert(abs(2*rad2deg(tv.lens.angleAt(L, ar)) - e.vfov) < 1)
    assert(abs(2*rad2deg(tv.lens.angleAt(L, hypot(1, ar))) - e.dfov) < 1)
end

%% The Wide model reproduces all six published Wide angles within 1 degree
for a = {'16:9', '4:3'}
    W = tv.lens.build(cfg.lenses, 'Wide', a{1});
    e = cfg.lenses(arrayfun(@(x) strcmp(x.name, 'Wide') && strcmp(x.aspect, a{1}), cfg.lenses));
    ar = W.heightPx / W.widthPx;
    got = 2 * rad2deg(tv.lens.angleAt(W, [1, ar, hypot(1, ar)]));
    assert(max(abs(got - [e.hfov, e.vfov, e.dfov])) < 1)
end

%% A point straight ahead lands in the middle of the picture
[u, v, ok] = tv.lens.project(W, cam, cam.pos + 10 * cam.R(3, :));
assert(ok && abs(u) < 1e-9 && abs(v) < 1e-9)

%% Right is right and down is down
[u, v] = tv.lens.project(W, cam, cam.pos + 10 * cam.R(3, :) + cam.R(1, :) + cam.R(2, :));
assert(u > 0 && v > 0)
