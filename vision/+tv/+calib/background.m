function bg = background(info, nSamples, tRange)
%BACKGROUND  The empty court: per-pixel median of frames spread over time (TV-CAL-10).
%   Moving players and the ball vanish in the median. nSamples frames
%   (default 61) are spread evenly over tRange = [t0 t1] seconds of the file
%   (default the whole file). Returns double 0-255, H-by-W-by-3.
%   RETUNE(real footage): the spec asks for ~200 frames over a quiet minute;
%   a player standing still for most of the window stays in the median.
if nargin < 2 || isempty(nSamples), nSamples = 61; end
if nargin < 3 || isempty(tRange), tRange = [info.pts(1), info.pts(end)]; end
idx = round(linspace(tRange(1), tRange(2), nSamples) * info.fps);
idx = unique(min(max(idx, 0), info.nFrames - 1));
stack = zeros(info.height, info.width, 3, numel(idx), 'uint8');
for k = 1:numel(idx)
    stack(:, :, :, k) = tv.media.readFrames(info, idx(k), 1);
end
bg = double(median(stack, 4));
end
