function [mask, white] = linePixels(img, opts)
%LINEPIXELS  Thin centre lines of the white court lines (and net tape) in an image.
%   A line pixel is brighter than the pixels a few pixels away on BOTH sides,
%   across the line (a ridge), and is not coloured. Edges such as the sky
%   above a dark fence are bright on one side only, so they drop out. Then
%   thinned to one pixel (TV-CAL-10: threshold, thin).
%   RETUNE(real footage): ridge contrast (opts.minContrast, 6 levels), its
%   reach (opts.reach, 3 px) and the colour limit (opts.maxSat, 0.5) suit
%   clean synthetic lines; sun, shadows and worn paint will need new values.
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'minContrast'), opts.minContrast = 6; end
if ~isfield(opts, 'reach'), opts.reach = 3; end
if ~isfield(opts, 'maxSat'), opts.maxSat = 0.5; end
img  = double(img);
g    = mean(img, 3);
k    = opts.reach;
sh   = @(dy, dx) g(min(max((1:end) + dy, 1), end), min(max((1:end) + dx, 1), end));
across = max(min(g - sh(-k, 0), g - sh(k, 0)), ...       % brighter than above and below
             min(g - sh(0, -k), g - sh(0, k)));          % or than left and right
across = max(across, min(g - sh(-k, -k), g - sh(k, k))); % diagonals
across = max(across, min(g - sh(-k, k), g - sh(k, -k)));
mx = max(img, [], 3);  mn = min(img, [], 3);
sat = (mx - mn) ./ max(mx, 1);
white = across > opts.minContrast & sat < opts.maxSat;
white = bwareaopen(white, 3);                           % drop specks
mask = bwmorph(white, 'thin', Inf);
end
