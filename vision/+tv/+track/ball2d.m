function tracks = ball2d(C, opts)
%BALL2D  Link ball candidates into 2D tracks in one camera (TV-TRK-01, TV-TRK-03).
%   C: candidates [frame u v area elongation score] (tv.detect.ballCandidates),
%   frame numbers absolute. Each track runs a Kalman filter with a
%   constant-acceleration model per image axis; a candidate joins the track
%   whose prediction it is closest to, inside a gate. A track survives up to
%   opts.maxMissed frames with no candidate (behind a player or the net
%   post). Several balls get several tracks. Short tracks and tracks that
%   barely move (a ball lying on court), or that are seen in too few of their
%   frames (noise at a player's edge), are dropped.
%   Returns a struct array: frames, uv (N-by-2), area, id.
%   RETUNE(real footage): gate sizes, noise levels, minimum length and the
%   maximum first jump (opts.maxJump, px per frame: depends on resolution).
if nargin < 2, opts = struct(); end
d = struct('maxMissed', 10, 'maxJump', 40, 'gateMin', 4, 'gateSigma', 4, ...
           'minLength', 8, 'minTravel', 15, 'minDensity', 0.6, 'q', 0.6, 'r', 0.7);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
dt = 1;
A = [1 dt dt^2/2; 0 1 dt; 0 0 1];
Q = opts.q^2 * [dt^5/20 dt^4/8 dt^3/6; dt^4/8 dt^3/3 dt^2/2; dt^3/6 dt^2/2 dt];
Hm = [1 0 0];  Rm = opts.r^2;
active = struct('x', {}, 'Px', {}, 'y', {}, 'Py', {}, 'frames', {}, 'uv', {}, 'area', {}, 'missed', {}, 'n', {});
done = active;
frames = unique(C(:, 1))';
if isempty(frames), tracks = struct('frames', {}, 'uv', {}, 'area', {}, 'id', {}); return; end
for f = frames(1):frames(end)
    rows = C(C(:, 1) == f, :);
    % predict
    for t = 1:numel(active)
        [active(t).x, active(t).Px] = predict(active(t).x, active(t).Px);
        [active(t).y, active(t).Py] = predict(active(t).y, active(t).Py);
    end
    % gated greedy assignment, closest pairs first
    used = false(size(rows, 1), 1);  took = false(numel(active), 1);
    if ~isempty(rows) && ~isempty(active)
        cost = inf(numel(active), size(rows, 1));
        for t = 1:numel(active)
            pu = active(t).x(1);  pv = active(t).y(1);
            s = sqrt(max(active(t).Px(1,1), active(t).Py(1,1)) + Rm);
            gate = max(opts.gateMin, opts.gateSigma * s);
            if active(t).n == 1, gate = opts.maxJump; end
            dd = hypot(rows(:, 2) - pu, rows(:, 3) - pv);
            dd(dd > gate) = inf;
            cost(t, :) = dd';
        end
        while true
            [m, i] = min(cost(:));
            if isempty(m) || ~isfinite(m), break; end
            [t, j] = ind2sub(size(cost), i);
            active(t) = update(active(t), rows(j, :), f);
            used(j) = true;  took(t) = true;
            cost(t, :) = inf;  cost(:, j) = inf;
        end
    end
    for t = find(~took)', active(t).missed = active(t).missed + 1; end
    % retire lost tracks
    lost = [active.missed] > opts.maxMissed;
    if any(lost), done = [done, active(lost)]; active = active(~lost); end %#ok<AGROW>
    % start new tracks
    for j = find(~used)'
        trk.x = [rows(j, 2); 0; 0];  trk.Px = diag([Rm, 30^2, 3^2]);
        trk.y = [rows(j, 3); 0; 0];  trk.Py = diag([Rm, 30^2, 3^2]);
        trk.frames = f;  trk.uv = rows(j, 2:3);  trk.area = rows(j, 4);  trk.missed = 0;  trk.n = 1;
        active(end+1) = trk; %#ok<AGROW>
    end
end
done = [done, active];
tracks = struct('frames', {}, 'uv', {}, 'area', {}, 'id', {});
for t = 1:numel(done)
    k = done(t);
    if numel(k.frames) < opts.minLength, continue; end
    span = max(k.uv) - min(k.uv);
    if norm(span) < opts.minTravel, continue; end
    % a ball in flight is seen in most frames; flicker at a player's edge is not
    if numel(k.frames) / (k.frames(end) - k.frames(1) + 1) < opts.minDensity, continue; end
    tracks(end+1) = struct('frames', k.frames(:), 'uv', k.uv, 'area', k.area(:), 'id', numel(tracks) + 1); %#ok<AGROW>
end

    function [x, P] = predict(x, P)
        x = A * x;  P = A * P * A' + Q;
    end
    function trk = update(trk, row, f)
        if trk.n == 1
            % second point: set velocity directly
            gap = f - trk.frames(end);
            trk.x = [row(2); (row(2) - trk.uv(end, 1)) / gap; 0];
            trk.y = [row(3); (row(3) - trk.uv(end, 2)) / gap; 0];
            trk.Px = diag([Rm, 2 * Rm, 4]);  trk.Py = trk.Px;
        else
            [trk.x, trk.Px] = correct(trk.x, trk.Px, row(2));
            [trk.y, trk.Py] = correct(trk.y, trk.Py, row(3));
        end
        trk.frames(end+1) = f;  trk.uv(end+1, :) = row(2:3);  trk.area(end+1) = row(4);
        trk.missed = 0;  trk.n = trk.n + 1;
    end
    function [x, P] = correct(x, P, z)
        S = Hm * P * Hm' + Rm;  K = P * Hm' / S;
        x = x + K * (z - Hm * x);  P = (eye(3) - K * Hm) * P;
    end
end
