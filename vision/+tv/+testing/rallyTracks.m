function [tracks, rec, sync] = rallyTracks(cams, flights, fps, blind, noisePx, seed)
%RALLYTRACKS  Each camera's 2D ball track through a rally of several flights (tests).
%   flights: N-by-2 cell, each row {session times, positions}. A frame has the ball when a
%   flight covers its time. blind = [camera t0 t1]: that camera reports nothing between
%   t0 and t1 (rows for several stretches; empty for none). noisePx: detector noise (sd),
%   the same every run for a given seed (no random-number state is touched).
%   Returns tracks{k} (frames 0-based, uv), rec (pts, height) and a sync with no offsets.
if nargin < 4, blind = zeros(0, 3); end
if nargin < 5, noisePx = 0.5; end
if nargin < 6, seed = 1; end
tEnd = max(cellfun(@(t) t(end), flights(:, 1))) + 1;
N = ceil(tEnd * fps);
tracks = cell(1, 2);
for k = 1:2
    pts = (0:N - 1)' / fps;
    rec(k) = struct('pts', pts, 'height', cams(k).height); %#ok<AGROW>
    B = nan(N, 3);
    for i = 1:size(flights, 1)
        in = pts >= flights{i, 1}(1) & pts < flights{i, 1}(end);
        B(in, :) = interp1(flights{i, 1}, flights{i, 2}, pts(in));
    end
    ok = all(isfinite(B), 2);
    for b = blind(blind(:, 1) == k, :)', ok = ok & ~(pts >= b(2) & pts <= b(3)); end
    f = find(ok);
    [px, vis] = tv.camera.project(cams(k), B(f, :));
    u1 = mod(sin((f + 31 * seed) * 12.9898 + k * 78.233) * 43758.5453, 1);
    u2 = mod(sin((f + 17 * seed) * 39.3468 + k * 11.135) * 24634.6345, 1);
    rr = noisePx * sqrt(-2 * log(max(u1, 1e-12)));
    px = px + [rr .* cos(2 * pi * u2), rr .* sin(2 * pi * u2)];
    tracks{k} = struct('frames', f(vis) - 1, 'uv', px(vis, :));
end
sync = struct('startOffset', [0 0], 'delta', 0, 'drift', 0, 'tref', 0, 'readout', [0 0], 'shutter', 0);
end
