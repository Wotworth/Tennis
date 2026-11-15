function [tracks, info] = track(samples, opts)
%TRACK  One track per person for the whole session, and which one is Chris (TV-PLY-02 to 07).
%   samples: struct array, one per sample time, with t and dets (people
%   from both cameras, tv.players.detect, already placed on the court).
%   Detections from the two cameras within opts.sameM metres are one person
%   (they check each other; one camera is enough when the other is blocked).
%   Tracks link people by court position and shirt colour; a track that
%   loses its person coasts at its last speed for up to opts.coastS seconds
%   (two players passing at a changeover may merge into one blob for a
%   moment). The track that shows the magenta cap is Chris; his track keeps
%   that identity after the cap comes off (TV-PLY-04).
%   info.chris: index of Chris's track (0 if none). info.confidence per
%   track (TV-PLY-07): below 0.9 the app must ask "Which one is you?".
%   RETUNE(real footage): opts.sameM, opts.gateM, opts.maxSpeed, opts.colourWeight and the
%   cap evidence needed (opts.capMin, opts.capSamples).
if nargin < 2, opts = struct(); end
d = struct('sameM', 1.2, 'gateM', 1.0, 'maxSpeed', 7, 'coastS', 1.5, 'colourWeight', 0.01, 'capMin', 0.15, 'capSamples', 3);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
tracks = struct('t', {}, 'xy', {}, 'cap', {}, 'shirt', {}, 'height', {}, 'v', {}, 'lastT', {}, 'ambiguous', {});
for si = 1:numel(samples)
    s = samples(si);
    dets = mergeCameras(s.dets, opts.sameM);
    % predict
    pred = zeros(numel(tracks), 2);
    for k = 1:numel(tracks)
        pred(k, :) = tracks(k).xy(end, :) + tracks(k).v * (s.t - tracks(k).lastT);
    end
    alive = find(arrayfun(@(tr) s.t - tr.lastT <= opts.coastS, tracks));
    cost = inf(numel(alive), numel(dets));
    for a = 1:numel(alive)
        k = alive(a);
        for j = 1:numel(dets)
            dist = norm(dets(j).foot - pred(k, :));
            if dist > opts.gateM + opts.maxSpeed * (s.t - tracks(k).lastT), continue; end
            col = norm(dets(j).shirt - median(tracks(k).shirt, 1));
            cost(a, j) = dist + opts.colourWeight * col;
        end
    end
    took = false(1, numel(dets));
    % a detection two tracks both want is ambiguous (people overlapping)
    wanted = sum(isfinite(cost), 1);
    while true
        [m, i] = min(cost(:));
        if isempty(m) || ~isfinite(m), break; end
        [a, j] = ind2sub(size(cost), i);  k = alive(a);
        tr = tracks(k);
        dtv = max(s.t - tr.lastT, 1e-3);
        tr.v = 0.5 * tr.v + 0.5 * (dets(j).foot - tr.xy(end, :)) / dtv;
        tr.t(end+1, 1) = s.t;  tr.xy(end+1, :) = dets(j).foot;  tr.cap(end+1, 1) = dets(j).cap;
        tr.shirt(end+1, :) = dets(j).shirt;  tr.height(end+1, 1) = dets(j).height;  tr.lastT = s.t;
        tr.ambiguous(end+1, 1) = wanted(j) > 1;
        tracks(k) = tr;  took(j) = true;
        cost(a, :) = inf;  cost(:, j) = inf;
    end
    for j = find(~took)
        tracks(end+1) = struct('t', s.t, 'xy', dets(j).foot, 'cap', dets(j).cap, 'shirt', dets(j).shirt, ... %#ok<AGROW>
            'height', dets(j).height, 'v', [0 0], 'lastT', s.t, 'ambiguous', false);
    end
end
% drop fleeting tracks (someone walking past, noise)
keep = arrayfun(@(tr) numel(tr.t) >= 5, tracks);
tracks = tracks(keep);
info.chris = 0;  info.confidence = ones(1, numel(tracks));
best = 0;
for k = 1:numel(tracks)
    n = nnz(tracks(k).cap >= opts.capMin);
    if n >= opts.capSamples && n > best, best = n; info.chris = k; end
end
for k = 1:numel(tracks)
    % every ambiguous moment after the last cap sighting chips at confidence
    lastCap = find(tracks(k).cap >= opts.capMin, 1, 'last');
    if isempty(lastCap), lastCap = 0; end
    info.confidence(k) = max(0, 1 - 0.02 * nnz(tracks(k).ambiguous(lastCap + 1:end)));
end
end

function out = mergeCameras(dets, sameM)
% one person seen by both cameras: average the positions
out = dets([]);
used = false(1, numel(dets));
for i = 1:numel(dets)
    if used(i), continue; end
    grp = i;
    for j = i + 1:numel(dets)
        if ~used(j) && norm(dets(i).foot - dets(j).foot) < sameM, grp(end+1) = j; used(j) = true; end %#ok<AGROW>
    end
    used(i) = true;
    m = dets(i);
    m.foot = mean(reshape([dets(grp).foot], 2, []), 2)';
    m.cap = max([dets(grp).cap]);
    m.shirt = mean(reshape([dets(grp).shirt], 3, []), 2)';
    m.height = median([dets(grp).height]);
    out(end+1) = m; %#ok<AGROW>
end
end
