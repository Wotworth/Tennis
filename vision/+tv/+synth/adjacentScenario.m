function sc = adjacentScenario()
%ADJACENTSCENARIO  The default session on a public court with a court on each side (TV-ADJ-07).
%   Chris's session (tv.synth.defaultScenario) plus:
%   - a court on each side, doubles sidelines 3.66 m apart (12 ft, the usual US
%     public-court spacing), lines painted, no fence between courts;
%   - two players and a ball in play on each, at the same time as Chris's rallies
%     (their own rallies, started at other moments, mirrored end to end);
%   - the hard cases: a neighbour's ball passing right behind Chris's ball in
%     camera 1's view, a stray ball rolling from the next court onto Chris's,
%     and a neighbour standing by the shared sideline, 1 m outside Chris's
%     court of interest.
%   The near court is mostly behind the cameras (they stand at its edge, as on a
%   fence between courts); the far court is in full view of both.
sc = tv.synth.defaultScenario();
c = tv.court.constants();
gap = 3.66;                                       % between the doubles sidelines
off = 2 * c.halfDoubles + gap;                    % court centre to court centre
sc.neighbourCourts = [-off, off];
sc.sideFence = false;
% their rallies: other starts, other shots (targets in their own court's frame)
nr(1).start = 3.1;   nr(1).server = 1;  nr(1).serverEnd = 1;
nr(1).shots = { [-5.2 -1.5], 36, 0.05, 'top';  [9.0 2.1], 24, 0.12, 'top';
                [-8.4 -3.4], 26, 0.12, 'top';  [10.2 0.9], 22, 0.10, 'top' };
nr(2).start = 18.2;  nr(2).server = 2;  nr(2).serverEnd = 1;
nr(2).shots = { [-4.9 2.2], 35, 0.05, 'top';  [8.1 -2.9], 25, 0.12, 'top';
                [-9.5 3.0], 27, 0.14, 'top';  [7.2 1.0], 20, 0.10, 'slice';
                [-10.4 -2.0], 26, 0.12, 'top' };
sc.neighbourRallies = nr;
% what the neighbours look like: no magenta caps (that is Chris's), no yellow shirts
sc.otherLooks = [ ...
    struct('name', 'N1', 'height', 1.78, 'shirt', [170 40 40], 'shorts', [30 30 35], 'cap', [240 240 240], 'capUntil', Inf), ...
    struct('name', 'N2', 'height', 1.70, 'shirt', [60 120 70], 'shorts', [200 200 200], 'cap', [30 30 30], 'capUntil', Inf), ...
    struct('name', 'N3', 'height', 1.85, 'shirt', [90 90 95], 'shorts', [40 40 60], 'cap', [30 30 30], 'capUntil', Inf), ...
    struct('name', 'N4', 'height', 1.66, 'shirt', [230 140 60], 'shorts', [30 30 35], 'cap', [240 240 240], 'capUntil', Inf), ...
    struct('name', 'Sideline', 'height', 1.82, 'shirt', [120 60 140], 'shorts', [30 30 35], 'cap', [30 30 30], 'capUntil', Inf)];
% hard cases
sc.crossing = struct('rally', 1, 'height', 1.3);  % neighbour's ball behind Chris's ball, camera 1
sc.roll = struct('start', 20.2, 'x', 6.0, 'from', off - 4, 'to', 2.0, 'speed', 4.0);   % onto Chris's court
sc.sidelineY = c.halfDoubles + 3.0;               % the neighbour by the shared sideline
end
