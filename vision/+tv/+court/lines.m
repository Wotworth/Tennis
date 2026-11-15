function L = lines()
%LINES  The court's painted lines as segments [x1 y1 x2 y2 halfWidth] (m).
%   Doubles and singles sidelines, baselines, service lines, the centre
%   service line and the centre marks. Lines are 5 cm wide; baselines are
%   drawn 8 cm wide (ITF allows up to 10 cm).
c = tv.court.constants();
X = c.halfLength;  D = c.halfDoubles;  S = c.halfSingles;  sv = c.serviceLine;
w = 0.025;  wb = 0.04;
L = [ -X -D  X -D  w;   -X  D  X  D  w;          % doubles sidelines
      -X -S  X -S  w;   -X  S  X  S  w;          % singles sidelines
      -X -D -X  D  wb;   X -D  X  D  wb;         % baselines
     -sv -S -sv  S  w;   sv -S  sv  S  w;        % service lines
     -sv  0  sv  0  w;                           % centre service line
      -X  0 -X+0.10 0 w;  X  0  X-0.10 0 w];     % centre marks
end
