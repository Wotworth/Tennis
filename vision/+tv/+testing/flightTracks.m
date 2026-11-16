function [tracks, rec] = flightTracks(cams, B, f, fps)
%FLIGHTTRACKS  Each camera's 2D track of 3D ball positions B (one row per frame f), and frame times (tests).
tracks = cell(1, 2);
for k = 1:2
    [px, ok] = tv.camera.project(cams(k), B);
    tracks{k} = struct('frames', f(ok), 'uv', px(ok, :));
    rec(k) = struct('pts', f / fps, 'height', cams(k).height); %#ok<AGROW>
end
end
