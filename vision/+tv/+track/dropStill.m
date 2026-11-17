function [kept, still, rate] = dropStill(trk, minPxPerFrame, window)
%DROPSTILL  Drop 2D tracks that barely move: balls lying on the court or by the fence, and
%   fixed bright spots (TV-TRK; footage test, 17 Nov). A ball in play always moves; a track
%   whose typical movement is under minPxPerFrame is not a ball in flight.
%   Movement is measured over `window` frames (the caller passes about a quarter second), so
%   a resting ball's pixel jitter averages out while real motion adds up; the median over the
%   track ignores the odd jump where the tracker hopped between two resting balls.
%   trk: tv.track.ball2d's tracks. kept: the moving tracks; still: logical, one per input;
%   rate: each track's median movement, px/frame.
%   The caller sets minPxPerFrame from a speed in m/s at the farthest point of interest
%   (tv.pipeline.runSingle: cfg.single.stillMps), so the rule is physical, not per-video.
%   RETUNE(real footage): the speed and the window (runSingle's stillMps, stillWindowS).
still = false(numel(trk), 1);  rate = nan(numel(trk), 1);
for i = 1:numel(trk)
    f = double(trk(i).frames(:));  uv = trk(i).uv;
    if numel(f) < 2, continue; end
    r = [];
    for a = 1:numel(f)
        b = find(f >= f(a) + window, 1);
        if isempty(b), break; end
        r(end+1) = norm(uv(b, :) - uv(a, :)) / (f(b) - f(a)); %#ok<AGROW>
    end
    if isempty(r), r = norm(uv(end, :) - uv(1, :)) / max(1, f(end) - f(1)); end
    rate(i) = median(r);
    still(i) = rate(i) < minPxPerFrame;
end
kept = trk(~still);
end
