function P = playVolume(behindBaseline, maxHeight, step)
%PLAYVOLUME  Sample points (N-by-3, m) of the volume both cameras must see.
%   TV-CAL-03: the doubles court plus BEHINDBASELINE metres behind each
%   baseline, from the ground (ball centre height) up to MAXHEIGHT. Points
%   are spaced about STEP metres apart and always include the edges and
%   corners, which are what decide coverage.
c  = tv.court.constants();
xe = c.halfLength + behindBaseline;
x  = linspace(-xe, xe, max(2, ceil(2*xe/step) + 1));
y  = linspace(-c.halfDoubles, c.halfDoubles, max(2, ceil(2*c.halfDoubles/step) + 1));
z  = linspace(c.ballRadius, maxHeight, max(2, ceil(maxHeight/step) + 1));
[X, Y, Z] = ndgrid(x, y, z);
P = [X(:), Y(:), Z(:)];
end
