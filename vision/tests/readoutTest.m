% Readout time from a flickering lamp's bands (TV-SYNC-06).
fps = 120000 / 1001;  N = 1200;  H = 135;                    % 10 s, rows binned
t = (0:N - 1)' / fps + 0.0003 * (rand(N, 1) - 0.5) / fps;    % frame times wobble a little
v = (0:H - 1) / H;
shade = 0.8 + 0.3 * exp(-((v - 0.4) / 0.5).^2);             % vignetting and the wall's shading

%% Finds the readout time and the lamp frequency
tauTrue = 0.0085;  fTrue = 120.04;
ph = 2 * pi * fTrue * (t + tauTrue * v);
prof = shade .* (1 + 0.06 * sin(ph) + 0.015 * cos(2 * ph)) + 0.002 * randn(N, H);
[tau, f, info] = tv.sync.readoutFromBands(prof, t);
assert(abs(tau - tauTrue) < 0.01 * tauTrue)
assert(abs(f - fTrue) < 0.01)
assert(info.contrast > 0.05)

%% A short readout (bands closer together than a frame) works too
tauTrue = 0.0042;
ph = 2 * pi * 120 * (t + tauTrue * v);
prof = shade .* (1 + 0.05 * sin(ph)) + 0.002 * randn(N, H);
tau = tv.sync.readoutFromBands(prof, t);
assert(abs(tau - tauTrue) < 0.01 * tauTrue)

%% At 4K240 (Chris, 21 Nov: the flicker clip in each camera's 4K240 mode): the 120 Hz lamp is half
% the frame rate, so the bands alternate from frame to frame and drift only slowly; 10 s still fits
fps = 240000 / 1001;  N = round(10 * fps);  H = 135;
t = (0:N - 1)' / fps + 0.0002 * (rand(N, 1) - 0.5) / fps;
v = (0:H - 1) / H;  shade = 0.8 + 0.3 * exp(-((v - 0.4) / 0.5).^2);
for tauTrue = [0.0035 0.006]
    ph = 2 * pi * 120.03 * (t + tauTrue * v);
    prof = shade .* (1 + 0.04 * sin(ph) + 0.01 * cos(2 * ph)) + 0.003 * randn(N, H);
    [tau, f] = tv.sync.readoutFromBands(prof, t);
    fprintf('4K240: readout %.3f ms found for %.3f ms (lamp %.3f Hz)\n', 1000 * tau, 1000 * tauTrue, f);
    assert(abs(tau - tauTrue) < 0.01 * tauTrue)
end
