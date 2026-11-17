function bg = background(info, nSamples, tRange, steadyMaxPx)
%BACKGROUND  The empty court: per-pixel median of frames spread over time (TV-CAL-10).
%   Moving players and the ball vanish in the median. nSamples frames
%   (default 61) are spread evenly over tRange = [t0 t1] seconds of the file
%   (default the whole file). steadyMaxPx > 0: each sample is first lined up with the middle
%   one (tv.calib.steady), for a camera that drifts. Returns double 0-255, H-by-W-by-3.
%   RETUNE(real footage): the spec asks for ~200 frames over a quiet minute;
%   a player standing still for most of the window stays in the median.
if nargin < 2 || isempty(nSamples), nSamples = 61; end
if nargin < 3 || isempty(tRange), tRange = [info.pts(1), info.pts(end)]; end
idx = round(linspace(tRange(1), tRange(2), nSamples) * info.fps);
idx = unique(min(max(idx, 0), info.nFrames - 1));
stack = zeros(info.height, info.width, 3, numel(idx), 'uint8');
ok = false(1, numel(idx));
for k = 1:numel(idx)
    % a frame that doesn't decode (the last frames of a file cut without re-encoding, 17 Nov)
    % is left out
    F = tv.media.readFrames(info, idx(k), 1);
    if size(F, 4) == 1, stack(:, :, :, k) = F; ok(k) = true; end
end
stack = stack(:, :, :, ok);
if nargin >= 4 && steadyMaxPx > 0
    % a camera that drifts (Chris's clay video, 17 Nov: up to 30 px over 15 min) smears the thin
    % lines in the median: line every sample up with the middle one first
    stack = tv.calib.steady(stack, double(stack(:, :, :, ceil(end / 2))), steadyMaxPx);
end
bg = double(median(stack, 4));
end
