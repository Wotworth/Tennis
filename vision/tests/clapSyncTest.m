% Timing and drift between the cameras from claps (Chris's home test c, 21 Nov; tools/syncFromClaps.m).

%% Claps at 0, 10, 20 and 30 minutes give the offset and the drift
fs = 8000;  T = 1850;
tv.util.seed(2);
tc = [20 620 1220 1820];                                % claps, camera 1's time (s)
dt0 = 0.37;  err = 0.0123;  drift = 40e-6;              % camera 2 starts 0.37 s later; timecode 12.3 ms off; 40 ppm
n = round(T * fs);  y1 = 0.01 * randn(n, 1);  y2 = 0.01 * randn(n, 1);
clap = @(len) randn(len, 1) .* exp(-(0:len - 1)' / (0.004 * fs));
for t = tc
    c = clap(200);                                       % the same clap reaches both cameras
    i = round(t * fs);  y1(i:i + 199) = y1(i:i + 199) + c;
    % camera 2 hears it at its own file time t2 = t - (dt0 + err) - drift * t (clock running slow)
    t2 = t - (dt0 + err) - drift * t;
    j = t2 * fs;  j0 = floor(j);  f = j - j0;
    c = 0.7 * c;                                         % farther from camera 2: quieter
    y2(j0:j0 + 200) = y2(j0:j0 + 200) + [(1 - f) * c; 0] + [0; f * c];   % placed between samples
end
y1(round(700 * fs) + (0:99)) = 0.5 * randn(100, 1);      % a knock only camera 1 heard: not matched
C = tv.sync.clapOffsets(y1, y2, fs, dt0);
disp(C)
assert(size(C, 1) == 4 && all(abs(C(:, 1) - tc') < 0.01))
p = polyfit(C(:, 1), C(:, 3), 1);
fprintf('offset at 0: %.3f ms (truth %.3f), drift %.1f ppm (truth 40)\n', 1000 * p(2), 1000 * (dt0 + err), 1e6 * p(1));
assert(abs(p(2) - (dt0 + err)) < 0.0002)                % 0.2 ms
assert(abs(p(1) - drift) < 2e-6)                         % 2 ppm
