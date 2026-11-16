function w = gust(g, t)
%GUST  Gusts on top of the mean wind for synthetic truth (m/s, 1x3, horizontal).
%   Three slow swirls with periods g.periods (s), amplitudes g.amp (m/s) and
%   random phases g.phase (3x2). Empty g: no gusts. With amplitudes of
%   0.6 m/s each the horizontal gust has a spread of about 1 m/s.
w = [0 0 0];
if isempty(g), return; end
for i = 1:numel(g.periods)
    w(1) = w(1) + g.amp(i) * cos(2 * pi * t / g.periods(i) + g.phase(i, 1));
    w(2) = w(2) + g.amp(i) * sin(2 * pi * t / g.periods(i) + g.phase(i, 2));
end
end
