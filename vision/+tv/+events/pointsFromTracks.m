function pts = pointsFromTracks(tracks, bounces, fps, opts)
%POINTSFROMTRACKS  Raw one-camera footage: the points, from where the ball is tracked (18 Nov).
%   tracks: cell array per clip of track structs (frames, 0-based); bounces: struct array with
%   frame and, when known, kind (tv.events.bounceKind). pts: rows [first last] frame.
%   - Only tracks at least opts.trackMinS long count: shorter ones are flickers and must not
%     bridge the quiet between two points.
%   - A point ends where nothing is tracked for opts.gapS.
%   - A point never runs through a ball bounced again and again on one spot (a 'dribble': the
%     server before the next serve): spans are cut opts.splitS either side of each, so the next
%     point starts with its serve.
%   - With opts.needsPlay, a point holds at least one bounce in play: balls picked up, rolled or
%     hit back between points are not points.
%   - Points shorter than opts.minS are dropped.
%   RETUNE(real footage): gapS 4, minS 1.5, splitS 0.5, trackMinS 0.5.
if nargin < 4, opts = struct(); end
d = struct('gapS', 4, 'minS', 1.5, 'splitS', 0.5, 'needsPlay', true, 'trackMinS', 0.5);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
fr = zeros(0, 1);
for r = 1:numel(tracks)
    for t = tracks{r}(:)'
        f = double(t.frames(:));
        if isempty(f) || f(end) - f(1) < opts.trackMinS * fps, continue; end
        fr = [fr; f]; %#ok<AGROW>
    end
end
pts = zeros(0, 2);
if isempty(fr), return; end
fr = unique(fr);
br = [0; find(diff(fr) > opts.gapS * fps); numel(fr)];
pts = [fr(br(1:end-1) + 1), fr(br(2:end))];
if isfield(bounces, 'kind') && ~isempty(bounces)
    kinds = {bounces.kind};  fb = double([bounces.frame]);
    cut = sort(fb(strcmp(kinds, 'dribble')));  w = opts.splitS * fps;
    Q = zeros(0, 2);
    for i = 1:size(pts, 1)
        a = pts(i, 1);
        for f = cut(cut >= pts(i, 1) & cut <= pts(i, 2))
            if f - w > a, Q(end+1, :) = [a, f - w]; end %#ok<AGROW>
            a = max(a, f + w);
        end
        if pts(i, 2) > a, Q(end+1, :) = [a, pts(i, 2)]; end %#ok<AGROW>
    end
    if opts.needsPlay
        fp = fb(strcmp(kinds, 'play'));
        Q = Q(arrayfun(@(i) any(fp >= Q(i, 1) & fp <= Q(i, 2)), (1:size(Q, 1))'), :);
    end
    pts = Q;
end
pts = pts(diff(pts, 1, 2) >= opts.minS * fps, :);
end
