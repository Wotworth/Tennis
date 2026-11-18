function [kind, cameM] = bounceKind(cam, B, P, fps, box, opts)
%BOUNCEKIND  One camera: is a bounce in play, bounced on the spot, or off the court? (18 Nov)
%   B: struct array of bounces with frame, u, v (pixels of the empty court) and x, y (m, on the
%   ground). P: every tracked ball point of the same clip, rows [frame u v]. box: the court of
%   interest (tv.court.interest).
%   kind (cell array):
%     'off'   the ground point is beside the court of interest (beyond its sides, within its
%             length): a ball on the next court. A bounce is on the ground, so this is exact
%             even with one camera (TV-ADJ-01).
%     'air'   the ground point is beyond the ends of the court of interest: the turn was not on
%             the ground at all (a hit or a ball against the back curtain, seen above the ground
%             behind it), so it is neither a bounce nor a sign of the next court.
%     'play'  the ball came from somewhere else: within opts.cameS seconds before the bounce,
%             some tracked point's sight line passes more than opts.cameM metres from the bounce
%             point (the closest the ball could have been to it, wherever it was along that line,
%             above the ground). A ball bounced by the server stays within about a metre.
%     'spot'  no such evidence: bounced on the spot (before a serve, off a racquet, dropped), or
%             too little track before it to tell.
%   kind 'spot' is 'dribble' instead when another bounce on the spot is within opts.repeatS
%   seconds and opts.repeatM metres of it: bounced again and again in one place, as servers do.
%   cameM: the distance measured (NaN without track before the bounce).
%   One camera behind a baseline cannot see how far a ball flying straight away from it has
%   come, so some far-end bounces in play are called 'spot'; two cameras measure it directly.
%   RETUNE(real footage): cameM 2.2 m (bounced balls measured up to 1.9 m, bounces in play from
%   3.1 m on the clay video), cameS 1 s, repeatS 3 s, repeatM 0.7 m.
if nargin < 6, opts = struct(); end
d = struct('cameM', 2.2, 'cameS', 1.0, 'skipS', 0.08, 'repeatS', 3.0, 'repeatM', 0.7);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
n = numel(B);  kind = cell(1, n);  cameM = NaN(1, n);
c = tv.court.constants();
for i = 1:n
    g = [B(i).x, B(i).y, c.ballRadius];
    if g(1) < box.x(1) || g(1) > box.x(2), kind{i} = 'air'; continue; end
    if g(2) < box.y(1) || g(2) > box.y(2), kind{i} = 'off'; continue; end
    q = P(P(:, 1) < B(i).frame - opts.skipS * fps & P(:, 1) >= B(i).frame - opts.cameS * fps, :);
    if ~isempty(q)
        R = tv.camera.rays(cam, q(:, 2:3));
        o = cam.pos(:)';
        smax = 60 * ones(size(R, 1), 1);                       % along the sight line: down to the ground
        dn = R(:, 3) < 0;  smax(dn) = -o(3) ./ R(dn, 3);
        s = min(max(R * (g - o)', 0), smax);
        cameM(i) = max(sqrt(sum((o + s .* R - g) .^ 2, 2)));
    end
    if cameM(i) > opts.cameM, kind{i} = 'play'; else, kind{i} = 'spot'; end
end
spot = find(strcmp(kind, 'spot'));
for i = spot
    for j = spot
        if i ~= j && abs(B(i).frame - B(j).frame) <= opts.repeatS * fps && hypot(B(i).x - B(j).x, B(i).y - B(j).y) <= opts.repeatM
            kind{i} = 'dribble';  break
        end
    end
end
end
