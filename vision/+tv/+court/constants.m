function c = constants()
%CONSTANTS  ITF standard court and ball (spec Part 1, "Constants"), in SI units.
%   Court frame (TV-ARCH-10): origin at the centre of the net on the ground;
%   x along the court's length (positive toward camera 2's baseline), y across
%   it (positive away from the cameras' fence), z up. Right-handed.

c.length          = 23.77;   % m, baseline to baseline
c.doublesWidth    = 10.97;   % m
c.singlesWidth    = 8.23;    % m
c.serviceLine     = 6.40;    % m from the net
c.netHeightCentre = 0.914;   % m at the centre strap
c.netHeightPost   = 1.07;    % m at the posts
c.postOutside     = 0.914;   % m, posts stand this far outside the doubles sideline
c.ballDiameter    = 0.0670;  % m (ITF range 6.54-6.86 cm)
c.ballMass        = 0.0577;  % kg (ITF range 56.0-59.4 g)
c.g               = 9.81;    % m/s^2

% Derived values used everywhere
c.halfLength      = c.length / 2;            % baseline at x = +/-11.885
c.halfDoubles     = c.doublesWidth / 2;      % doubles sideline at y = +/-5.485
c.halfSingles     = c.singlesWidth / 2;
c.postY           = c.halfDoubles + c.postOutside;
c.ballRadius      = c.ballDiameter / 2;      % ball centre height at a bounce
c.ballArea        = pi * c.ballRadius^2;     % cross-section A in the drag law
end
