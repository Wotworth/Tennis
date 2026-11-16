function [tau, info] = readoutFromFlicker(file, opts)
%READOUTFROMFLICKER  A camera's readout time from about 10 s of a wall lit by a flickering lamp (TV-SYNC-06).
%   tau = readoutFromFlicker('GX010042.MP4') reads up to 1200 frames (10 s), averages
%   each frame across its columns (the bands are horizontal) and fits the
%   bands (tv.sync.readoutFromBands). Record it at the session's shutter
%   speed, in each mode used, once per camera; the PC stores the result per
%   camera serial and mode as the session fit's readout prior.
%   opts.fNominal: twice the mains frequency (120 in the US, 100 in Europe).
if nargin < 2, opts = struct(); end
rec = tv.media.probe(file);
n = min(rec.nFrames, 1200);                        % about 10 s: the bands drift a full cycle
bin = 16;  nb = floor(rec.height / bin);           % 16-row bins: plenty for bands about a frame tall
prof = zeros(n, nb);
for k = 1:n
    img = double(tv.media.readFrames(rec, k - 1, 1));
    rows = mean(mean(img, 3), 2);
    prof(k, :) = mean(reshape(rows(1:nb * bin), bin, nb), 1);
end
opts.rowPos = ((0:nb - 1) * bin + (bin - 1) / 2) / rec.height;
[tau, f, info] = tv.sync.readoutFromBands(prof, rec.pts(1:n), opts);
info.f = f;
fprintf('%s: readout %.3f ms (lamp %.3f Hz, band contrast %.1f%%, residual %.4f)\n', file, 1000 * tau, f, 100 * info.contrast, info.rmsResidual);
if info.contrast < 0.01, warning('Bands are faint (under 1%%): use a lamp that flickers, or a faster shutter.'); end
end
