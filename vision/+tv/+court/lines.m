function L = lines()
%LINES  The court's painted lines as segments [x1 y1 x2 y2 halfWidth] (m): each line's centre.
%   Doubles and singles sidelines, baselines, service lines, the centre service line and the
%   centre marks. Lines are 5 cm wide; baselines are drawn 8 cm wide (ITF allows up to 10 cm).
%   20 Nov (Chris): a court's sizes are measured to the OUTSIDE edges of its lines, so each line's
%   centre lies half its width inside the nominal size: the baseline's at 11.885 - 0.04 m, the
%   doubles sideline's at 5.485 - 0.025 m, the service line's (6.40 m from the net to its edge
%   away from the net) at 6.40 - 0.025 m. Before, the centres sat on the nominal sizes, 2.5 to
%   4 cm too far out. The court's outer corner (where a tapped corner snaps to) is still exactly
%   (+/-11.885, +/-5.485), and in/out calls still use the nominal sizes (a ball touching the
%   line is in).
%   RETUNE(real court): the baseline's width (4 to 10 cm), measured on Tuesday's court.
c = tv.court.constants();
X = c.halfLength;  D = c.halfDoubles;  S = c.halfSingles;  sv = c.serviceLine;
w = 0.025;  wb = 0.04;
Xc = X - wb;  Dc = D - w;  Sc = S - w;  svc = sv - w;
L = [ -X -Dc  X -Dc  w;   -X  Dc  X  Dc  w;      % doubles sidelines (to the baselines' outer edges)
      -X -Sc  X -Sc  w;   -X  Sc  X  Sc  w;      % singles sidelines
      -Xc -D -Xc  D  wb;   Xc -D  Xc  D  wb;     % baselines (to the doubles sidelines' outer edges)
     -svc -S -svc  S  w;   svc -S  svc  S  w;    % service lines
     -svc  0  svc  0  w;                         % centre service line
      -(Xc - wb) 0 -(Xc - wb - 0.10) 0 w;  Xc - wb  0  Xc - wb - 0.10  0  w];   % centre marks, inside the baselines
end
