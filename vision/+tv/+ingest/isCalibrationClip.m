function tf = isCalibrationClip(file, nSamples)
%ISCALIBRATIONCLIP  True when a checkerboard shows in at least 30% of sampled frames (TV-ING-14).
%   Needs the Computer Vision Toolbox (detectCheckerboardPoints); without it
%   (Octave, a bare MATLAB) nothing counts as a calibration clip.
if nargin < 2, nSamples = 10; end
tf = false;
if ~exist('detectCheckerboardPoints', 'file'), return; end
info = tv.media.probe(file);
idx = round(linspace(0, info.nFrames - 1, nSamples));
hits = 0;
for n = idx
    img = tv.media.readFrames(info, n, 1, 0.5);
    [~, sz] = detectCheckerboardPoints(rgb2gray(img));
    hits = hits + any(sz > 0);
end
tf = hits / numel(idx) >= 0.3;
end
