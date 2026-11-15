function n = frameAt(k, t, rec, sync)
%FRAMEAT  The frame (0-based) of camera k nearest session time t (rolling shutter ignored).
r = rec(k);
if k == 2
    % invert t = t2 + delta + drift*(t2 - tref)
    t = (t - sync.delta + sync.drift * sync.tref) / (1 + sync.drift);
end
local = t - sync.startOffset(k);
n = round(interp1(r.pts, 0:numel(r.pts) - 1, local, 'linear', 'extrap'));
n = min(max(n, 0), r.nFrames - 1);
end
