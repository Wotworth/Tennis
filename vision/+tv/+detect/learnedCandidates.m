function rows = learnedCandidates(rec, bg, f0, f1, S, net, pre, opts)
%LEARNEDCANDIDATES  The learned ball detector over frames f0..f1 of one recording (TV-DET-04).
%   For every frame: the small things that move (tv.detect.motionProposals: no colour test), each
%   cut out at the ball's likely size there and scored by the first pass and the classifier
%   (tv.detect.ballScores: 0 to 1, the chance it is a ball). The same steps as the one-camera
%   path (tv.pipeline.runSingle), here for the two-camera pipeline (Chris, 19 Nov: wire the
%   learned detector in before the first GoPro footage).
%   rec: one recording (tv.media.probe). bg: its empty court (tv.calib.background). f0, f1:
%   0-based frame numbers. S: where a ball can be and how big it can look there
%   (tv.detect.ballSizeMap: mask, dmin, dmax; multiply dmin and dmax first if the footage draws the
%   ball larger). net, pre: the classifier and its first pass (tv.detect.loadBallNet; pre may be []).
%   rows: one per spot, [frame u v score dmin dmax area length width]; u, v are 1-based pixels of
%   the empty court's picture (each frame is lined up with bg first: a camera on a fence moves in
%   the wind, tv.calib.steady).
%   Only the part of the picture a ball can be in is worked on: the mask's bounding box, widened
%   by half a cut so the classifier's cuts never run off it. From beside the court that is most of
%   the frame; the pixels outside it cost nothing.
%   opts.chunk: frames decoded at a time (30). opts.steadyMaxPx: the largest camera shift taken
%   as real (40 px). The three frames looked at are 1/30 s apart, whatever the frame rate.
%   Nothing to tune here: the detector's own settings are in the functions it calls.
if nargin < 8, opts = struct(); end
if ~isfield(opts, 'chunk'), opts.chunk = 30; end
if ~isfield(opts, 'steadyMaxPx'), opts.steadyMaxPx = 40; end
rows = zeros(0, 9);
[rr, cc] = find(S.mask);
if isempty(rr), return; end
H = size(S.mask, 1);  W = size(S.mask, 2);
pad = ceil(4 * double(max(S.dmax(:)))) + 4;            % a cut is 8 diameters wide
r0 = max(1, min(rr) - pad);  r1 = min(H, max(rr) + pad);
c0 = max(1, min(cc) - pad);  c1 = min(W, max(cc) + pad);
Sb = struct('mask', S.mask(r0:r1, c0:c1), 'dmin', S.dmin(r0:r1, c0:c1), 'dmax', S.dmax(r0:r1, c0:c1));
bgb = double(bg(r0:r1, c0:c1, :));
h = r1 - r0 + 1;  w = c1 - c0 + 1;
K2 = max(1, round(2 * rec.fps / 60));                 % neighbours 1/30 s away
out = cell(0, 1);
for a = f0:opts.chunk:f1
    first = max(0, a - K2);
    n = min(opts.chunk + 2 * K2, rec.nFrames - first);
    if n < 2 * K2 + 1, break; end
    F = tv.media.readFrames(rec, first, n);
    F = F(r0:r1, c0:c1, :, :);
    for t = a:min(a + opts.chunk - 1, f1)
        j = t - first + 1;
        if j - K2 < 1 || j + K2 > size(F, 4), continue; end
        cur = F(:, :, :, j);
        [C, ~, prev, nxt] = tv.detect.motionProposals(F(:, :, :, j - K2), cur, F(:, :, :, j + K2), Sb);
        if isempty(C), continue; end
        ix = sub2ind([h w], min(max(round(C(:, 2)), 1), h), min(max(round(C(:, 1)), 1), w));
        M = double([Sb.dmin(ix), Sb.dmax(ix)]);
        sc = tv.detect.ballScale(C(:, 5), M);
        p = tv.detect.ballScores(net, pre, tv.detect.ballCrops(prev, cur, nxt, C, 48, sc), M ./ sc);
        [~, d] = tv.calib.steady(cur, bgb, opts.steadyMaxPx);
        m = size(C, 1);
        out{end+1, 1} = [repmat(t, m, 1), C(:, 1) + c0 - 1 - d(1), C(:, 2) + r0 - 1 - d(2), p(:), M, C(:, 3:5)]; %#ok<AGROW>
    end
end
if ~isempty(out), rows = vertcat(out{:}); end
end
