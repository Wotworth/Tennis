function rep = corners(cam, marginPx)
%CORNERS  Which court corners a camera sees, after its pose is fitted (TV-CAL-20, Chris 17 Nov).
%   The eight corners: singles and doubles, at both baselines. A corner is seen when it
%   projects in front of the camera and at least marginPx (default 10) inside the frame.
%   rep.names: e.g. 'near right doubles' ("near" = the baseline closer to this camera;
%   "right" as this camera sees it); rep.seen: true/false each; rep.missing: names not seen;
%   rep.text: one line for the session summary and the phone alert, '' when all are seen.
if nargin < 2, marginPx = 10; end
c = tv.court.constants();
xs = [-1 1] * c.halfLength;  ys = [-1 1];  widths = [c.halfSingles c.halfDoubles];  kinds = {'singles', 'doubles'};
P = zeros(0, 3);  near = [];  yv = [];  kind = {};
for x = xs
    for w = 1:2
        for s = ys
            P(end+1, :) = [x, s * widths(w), 0]; %#ok<AGROW>
            kind{end+1} = kinds{w}; %#ok<AGROW>
        end
    end
end
[px, ok] = tv.camera.project(cam, P);
W = cam.width;  H = cam.height;
inside = ok & px(:, 1) >= marginPx & px(:, 1) <= W - marginPx & px(:, 2) >= marginPx & px(:, 2) <= H - marginPx;
% near/far and left/right as this camera sees it
d = sqrt(sum((P - cam.pos).^2, 2));
fwd = cam.R(3, :);  right = cam.R(1, :);
names = cell(size(P, 1), 1);
for i = 1:size(P, 1)
    nearSide = abs(P(i, 1) - sign(cam.pos(1)) * c.halfLength) < 1e-6;
    if cam.pos(1) == 0, nearSide = d(i) <= median(d); end
    lr = 'left';  if (P(i, :) - cam.pos) * right' > 0, lr = 'right'; end
    nf = 'far';  if nearSide, nf = 'near'; end
    names{i} = sprintf('%s %s %s', nf, lr, kind{i});
end
rep.names = names;  rep.seen = inside;  rep.missing = names(~inside);
rep.text = '';
if any(~inside)
    rep.text = sprintf('Court corners out of view: %s. Shots there may be missed; check the framing before the next session.', ...
        strjoin(rep.missing', ', '));
end
end
