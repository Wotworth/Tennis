function R = recordings(archiveDir, roles)
%RECORDINGS  Every archived recording: camera, chapters, start and end UTC (TV-ING-10 to 13).
%   Walks archive/<date>/<serial>/, groups chapter files (tv.ingest.chapters),
%   and reads each recording's time span: the GPS clock when the camera had
%   a fix, else the camera's own clock (TV-ING-13). Calibration clips (a
%   checkerboard in at least 30% of sampled frames, TV-ING-14) are marked
%   and kept out of sessions. roles: struct array serial -> role.
%   Returns struct array: serial, role, files, startUtc (s since 2000),
%   endUtc, utcSource, lat, lon, calibration.
R = struct('serial', {}, 'role', {}, 'files', {}, 'startUtc', {}, 'endUtc', {}, ...
           'utcSource', {}, 'lat', {}, 'lon', {}, 'calibration', {});
days = dir(archiveDir);
for d = days(:)'
    if ~d.isdir || d.name(1) == '.', continue; end
    sers = dir(fullfile(archiveDir, d.name));
    for s = sers(:)'
        if ~s.isdir || s.name(1) == '.', continue; end
        folder = fullfile(archiveDir, d.name, s.name);
        mp4 = dir(fullfile(folder, '*.MP4'));
        if isempty(mp4), continue; end
        groups = tv.ingest.chapters({mp4.name});
        role = '';
        k = find(strcmp({roles.serial}, s.name), 1);
        if ~isempty(k), role = roles(k).role; end
        for g = groups(:)'
            files = fullfile(folder, g.files);
            first = tv.media.probe(files{1});
            dur = 0;
            for f = files(:)'
                info = tv.media.probe(f{1});
                dur = dur + info.pts(end) + 1 / info.fps;
            end
            src = 'camera clock';  t0 = tv.util.utcSeconds(first.startUtc);  lat = NaN;  lon = NaN;
            try
                G = tv.gpmf.summary(files{1});
                if isfinite(G.utcOffset), t0 = G.utcOffset; src = 'gps'; end
                fixed = G.payloads(G.payloads(:, 3) >= 2, :);
                if ~isempty(fixed), lat = median(fixed(:, 4)); lon = median(fixed(:, 5)); end
            catch
            end
            R(end+1) = struct('serial', s.name, 'role', role, 'files', {files}, 'startUtc', t0, ... %#ok<AGROW>
                'endUtc', t0 + dur, 'utcSource', src, 'lat', lat, 'lon', lon, ...
                'calibration', tv.ingest.isCalibrationClip(files{1}));
        end
    end
end
end
