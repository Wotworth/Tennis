function [mask, white] = linePixels(img, opts)
%LINEPIXELS  Thin centre lines of the white court lines (and net tape) in an image.
%   A line pixel is brighter than the pixels a few pixels away on BOTH sides,
%   across the line (a ridge), and is not coloured. Edges such as the sky
%   above a dark fence are bright on one side only, so they drop out. Then
%   thinned to one pixel (TV-CAL-10: threshold, thin).
%   RETUNE(real footage): ridge contrast (opts.minContrast, 6 levels), its
%   reach (opts.reach, 3 px; a list tries each) and the colour limit (opts.maxSat, 0.5) suit
%   clean synthetic lines; sun, shadows and worn paint will need new values.
%   Real footage (first test, Chris's iPhone video, 17 Nov): trees, fence mesh and
%   the net's mesh give short ridges. opts.minLength (px, default 0 = off) keeps
%   only thinned pieces at least that long; court lines are long and straight.
%   opts.maxPieceSat (default Inf = off) drops pieces whose median colour saturation is
%   above it: coloured tape (pickleball lines) as opposed to white paint.
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'minContrast'), opts.minContrast = 6; end
if ~isfield(opts, 'reach'), opts.reach = 3; end
if ~isfield(opts, 'maxSat'), opts.maxSat = 0.5; end
if ~isfield(opts, 'minLength'), opts.minLength = 0; end
if ~isfield(opts, 'maxPieceSat'), opts.maxPieceSat = Inf; end
img  = double(img);
g    = mean(img, 3);
across = -inf(size(g));
for k = opts.reach(:)'                                  % several reaches: near lines are wide
    sh   = @(dy, dx) g(min(max((1:end) + dy, 1), end), min(max((1:end) + dx, 1), end));
    across = max(across, max(min(g - sh(-k, 0), g - sh(k, 0)), ...   % brighter than above and below
                             min(g - sh(0, -k), g - sh(0, k))));      % or than left and right
    across = max(across, min(g - sh(-k, -k), g - sh(k, k)));         % diagonals
    across = max(across, min(g - sh(-k, k), g - sh(k, -k)));
end
mx = max(img, [], 3);  mn = min(img, [], 3);
sat = (mx - mn) ./ max(mx, 1);
white = across > opts.minContrast & sat < opts.maxSat;
white = bwareaopen(white, 3);                           % drop specks
mask = bwmorph(white, 'thin', Inf);
if opts.minLength > 0
    % length of a thinned piece ~ its pixel count; break junctions so mesh grids fall apart
    nb = conv2(double(mask), [1 1 1; 1 0 1; 1 1 1], 'same');
    pieces = mask & ~(mask & nb > 2);
    pieces = bwareaopen(pieces, opts.minLength, 8);
    if isfinite(opts.maxPieceSat)
        % coloured tape (a pickleball court taped over the tennis court, common on public
        % courts) is pale enough to pass the pixel colour limit; judged per piece, by its
        % median colour, white paint stays near 0.06 and pink tape near 0.23 (17 Nov)
        [lab, n] = bwlabel(pieces, 8);
        if n > 0
            ms = accumarray(lab(lab > 0), sat(lab > 0), [n 1], @median);
            pieces(lab > 0) = ms(lab(lab > 0)) <= opts.maxPieceSat;
        end
    end
    mask = mask & imdilate(pieces, true(3));
end
end
