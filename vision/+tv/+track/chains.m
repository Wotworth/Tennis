function [tracks, value] = chains(D, opts)
%CHAINS  The ball's path through time from scored detections (TV-TRK, 18 Nov): one ball in play.
%   D: rows [frame x y score dmin dmax] (score: the learned classifier's ball probability).
%   Each detection is worth logit(score): positive where the classifier says ball, negative where
%   not. A chain may link two detections up to opts.gap frames apart when the speed between them
%   is one a ball can have there (up to 12 diameters a frame plus 6 px), at opts.gapCost per frame
%   jumped and opts.turnCost per px/frame of change in velocity (gravity and drag change it slowly;
%   a hit or a bounce starts a new chain). The best chain is taken, its detections (and anything
%   within 3 px of them in the same frame) removed, and so on while a chain is worth opts.minValue.
%   tracks: struct array as tv.track.ball2d's (frames, uv, area, id, score); value: each chain's
%   worth. The ball in play at a frame is the most valuable chain there (tv.track.inPlay).
%   Times and speeds are set for 60 frames a second; opts.fps scales them to the video's own
%   rate (the gap is 8/60 s whatever the rate, speeds are per 1/60 s), so a 30 fps phone video
%   needs no retuning.
if nargin < 2, opts = struct(); end
d = struct('gap', 8, 'gapCost', 0.4, 'turnCost', 0.15, 'minValue', 6, 'minLen', 5, 'step', 1, 'fps', 60);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
u = opts.fps / 60;                                     % this video's frames per 1/60 s
gapF = max(opts.step, round(opts.gap * u));
tracks = struct('frames', {}, 'uv', {}, 'area', {}, 'id', {}, 'score', {});  value = zeros(0, 1);
if isempty(D), return; end
D = sortrows(D, 1);
n = size(D, 1);
w = min(max(log(max(D(:, 4), 1e-4) ./ max(1 - D(:, 4), 1e-4)), -6), 6);
fr = D(:, 1);
[uf, ~, grp] = unique(fr);
byF = accumarray(grp, (1:n)', [], @(x) {x});
alive = true(n, 1);
while true
    val = -Inf(n, 1);  pred = zeros(n, 1);  vel = zeros(n, 2);
    for gi = 1:numel(uf)
        f = uf(gi);
        for b = byF{gi}'
            if ~alive(b), continue; end
            best = w(b);  bp = 0;  bv = [0 0];
            dm = 0.5 * (D(b, 5) + D(b, 6));  vmax = 12 * max(dm, 3) + 6;
            for g = opts.step:opts.step:gapF
                ga = find(uf == f - g, 1);
                if isempty(ga), continue; end
                for a = byF{ga}'
                    if ~alive(a) || ~isfinite(val(a)), continue; end
                    v = (D(b, 2:3) - D(a, 2:3)) / g * u;      % px per 1/60 s
                    if hypot(v(1), v(2)) > vmax, continue; end
                    turn = 0;  if pred(a) > 0, turn = hypot(v(1) - vel(a, 1), v(2) - vel(a, 2)); end
                    c = val(a) + w(b) - opts.gapCost * (g - opts.step) / opts.step / u - opts.turnCost * turn;
                    if c > best, best = c;  bp = a;  bv = v; end
                end
            end
            val(b) = best;  pred(b) = bp;  vel(b, :) = bv;
        end
    end
    val(~alive) = -Inf;
    [vb, e] = max(val);
    if ~isfinite(vb) || vb < opts.minValue, break; end
    path = e;
    while pred(path(end)) > 0, path(end+1) = pred(path(end)); end %#ok<AGROW>
    path = flip(path);
    for i = path
        alive(fr == fr(i) & hypot(D(:, 2) - D(i, 2), D(:, 3) - D(i, 3)) < 3) = false;
    end
    alive(path) = false;
    if numel(path) >= opts.minLen
        tracks(end+1) = struct('frames', fr(path), 'uv', D(path, 2:3), 'area', zeros(numel(path), 1), ...
            'id', numel(tracks) + 1, 'score', D(path, 4)); %#ok<AGROW>
        value(end+1, 1) = vb; %#ok<AGROW>
    end
end
end
