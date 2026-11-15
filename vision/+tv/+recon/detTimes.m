function t = detTimes(k, frame, v, rec, sync)
%DETTIMES  Session time (s) at which camera k saw each detection.
%   Session time is camera 1's file time (0 at its first frame). For each
%   detection: the frame's own time stamp (never frame/fps: TV-ING-10), plus
%   the rolling-shutter delay of its image row v (row 1 first, the last row
%   readout seconds later), plus half the shutter time. Camera 2's time is
%   mapped onto camera 1's clock: t1 = t2 + Delta + epsilon*(t2 - tref),
%   with t2 already shifted by the coarse start-time difference (TV-SYNC).
%   rec(k): .pts, .height; sync: .startOffset(k), .delta, .drift, .tref,
%   .readout(k), .shutter.
r = rec(k);
t = sync.startOffset(k) + r.pts(frame(:) + 1) + sync.readout(k) * (v(:) - 1) / r.height + sync.shutter / 2;
if k == 2
    t = t + sync.delta + sync.drift * (t - sync.tref);
end
end
