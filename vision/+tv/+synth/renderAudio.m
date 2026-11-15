function [y, fs] = renderAudio(cam, sc, truth)
%RENDERAUDIO  One camera's sound track: racquet hits and bounces, as heard there.
%   Each sound leaves its 3D source at the truth time and reaches the camera
%   after distance / speed of sound (TV-SYNC-02), then is stamped in that
%   camera's own clock (offset and drift). Mono, 48 kHz, -1..1.
%   RETUNE(real footage): real hits, bounces, voices, wind and other courts
%   sound different; the onset detector's thresholds are set on these.
fs = 48000;
n  = round(sc.duration * fs) + 1;
tv.util.seed(sc.seed + 100 * cam.recordStart);
y  = 0.003 * randn(n, 1);
cs = tv.air.speedOfSound(sc.weather.tempC);
ev = zeros(0, 5);                                    % [T x y z amplitude]
for s = truth.shots'
    ev(end+1, :) = [s.tHit, s.pHit, 0.6]; %#ok<AGROW>
    if ~isnan(s.tBounce), ev(end+1, :) = [s.tBounce, s.pBounce, 0.2]; end %#ok<AGROW>
end
tv.util.seed(sc.seed);
burst = randn(round(0.006 * fs), 1);
tb = (0:numel(burst) - 1)' / fs;
for k = 1:size(ev, 1)
    d = norm(ev(k, 2:4) - cam.pos);
    Tarr = ev(k, 1) + d / cs;
    clock = (Tarr - cam.clockOffset) / (1 + cam.clockDrift);   % inverse of tv.synth.truthTime
    i0 = round((clock - cam.recordStart) * fs) + 1;
    if i0 < 1 || i0 + numel(burst) > n, continue; end
    w = ev(k, 5) / (1 + d / 10) * (burst .* exp(-tb / 0.0015) + 0.5 * sin(2*pi*1200*tb) .* exp(-tb / 0.002));
    y(i0:i0 + numel(w) - 1) = y(i0:i0 + numel(w) - 1) + w;
end
y = max(-1, min(1, y));
end
