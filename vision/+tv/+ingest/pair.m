function [sessions, waiting] = pair(R, nowUtc, opts)
%PAIR  Sessions from recordings: cam1 and cam2 footage whose times overlap (TV-ING-20, 21).
%   R: tv.ingest.recordings. A camera-1 recording and a camera-2 recording
%   that overlap in UTC form a session. A recording with no partner yet
%   waits; after opts.waitHours (24) it becomes a single-camera session,
%   marked 'reduced' (rally reel and 2D bounce map only), with an alert.
%   Calibration clips never form sessions. nowUtc: seconds since 2000.
%   sessions: struct array: cam1, cam2 (indices into R, 0 if missing),
%   startUtc, mode ('full' or 'reduced').
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'waitHours'), opts.waitHours = 24; end
sessions = struct('cam1', {}, 'cam2', {}, 'startUtc', {}, 'mode', {});
waiting = [];
use = find(~[R.calibration]);
c1 = use(strcmp({R(use).role}, 'cam1'));  c2 = use(strcmp({R(use).role}, 'cam2'));
paired2 = false(size(c2));
for i = c1
    j = 0;
    for jj = 1:numel(c2)
        b = R(c2(jj));
        if ~paired2(jj) && b.startUtc < R(i).endUtc && R(i).startUtc < b.endUtc, j = jj; break; end
    end
    if j > 0
        paired2(j) = true;
        sessions(end+1) = struct('cam1', i, 'cam2', c2(j), 'startUtc', min(R(i).startUtc, R(c2(j)).startUtc), 'mode', 'full'); %#ok<AGROW>
    elseif nowUtc - R(i).endUtc > opts.waitHours * 3600
        sessions(end+1) = struct('cam1', i, 'cam2', 0, 'startUtc', R(i).startUtc, 'mode', 'reduced'); %#ok<AGROW>
    else
        waiting(end+1) = i; %#ok<AGROW>
    end
end
for jj = find(~paired2)
    j = c2(jj);
    if nowUtc - R(j).endUtc > opts.waitHours * 3600
        sessions(end+1) = struct('cam1', 0, 'cam2', j, 'startUtc', R(j).startUtc, 'mode', 'reduced'); %#ok<AGROW>
    else
        waiting(end+1) = j; %#ok<AGROW>
    end
end
end
