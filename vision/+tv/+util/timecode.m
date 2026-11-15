function tc = timecode(isoUtc, fps)
%TIMECODE  HH:MM:SS:FF for an ISO UTC time, FF counted at round(fps) frames per second.
if nargin < 2, fps = 120; end
v = sscanf(isoUtc, '%d-%d-%dT%d:%d:%f');
tc = sprintf('%02d:%02d:%02d:%02d', v(4), v(5), floor(v(6)), floor(mod(v(6), 1) * round(fps)));
end
