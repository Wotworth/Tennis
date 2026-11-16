function [tracks, cands, rec, sync] = ballTracks(cams, balls, fps, noisePx)
%BALLTRACKS  Per-camera 2D tracks and candidates of several 3D balls (tests).
%   balls: cell of N-by-3 positions, one row per frame 0..N-1 (NaN: not there).
%   Each ball becomes one track per camera (perfect linking; the gate is what is
%   tested). Returns tracks{k} (frames, uv, area, id), cands{k} [frame u v area 1 1],
%   rec (pts, height) and a sync with no offsets.
if nargin < 4, noisePx = 0.3; end
N = size(balls{1}, 1);
tracks = cell(1, 2);  cands = cell(1, 2);
for k = 1:2
    tracks{k} = struct('frames', {}, 'uv', {}, 'area', {}, 'id', {});
    cands{k} = zeros(0, 6);
    for b = 1:numel(balls)
        [px, ok] = tv.camera.project(cams(k), balls{b});
        ok = ok & all(isfinite(balls{b}), 2);
        if nnz(ok) < 3, continue; end
        f = find(ok) - 1;
        uv = px(ok, :) + noisePx * randn(nnz(ok), 2);
        tracks{k}(end+1) = struct('frames', f(:), 'uv', uv, 'area', 20 * ones(nnz(ok), 1), 'id', numel(tracks{k}) + 1);
        cands{k} = [cands{k}; f(:), uv, 20 * ones(nnz(ok), 1), ones(nnz(ok), 2)];
    end
    rec(k) = struct('pts', (0:N - 1)' / fps, 'height', cams(k).height); %#ok<AGROW>
end
sync = struct('startOffset', [0 0], 'delta', 0, 'drift', 0, 'tref', 0, 'readout', [0 0], 'shutter', 0);
end
