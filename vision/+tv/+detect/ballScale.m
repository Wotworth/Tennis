function s = ballScale(width, M)
%BALLSCALE  The ball's likely diameter (px) at each candidate spot (round 4, 18 Nov): its blob's
%   width (tv.detect.motionProposals, column 5), kept within the range the camera's geometry
%   allows there (M: N-by-2, [dmin dmax] from tv.detect.ballSizeMap). tv.detect.ballCrops cuts
%   each spot at this scale, so the classifier sees a ball of the same size whatever the camera,
%   its resolution or the distance.
lo = max(M(:, 1), 1);  hi = max(M(:, 2), lo);
s = min(max(max(width(:), 2), lo), hi);
end
