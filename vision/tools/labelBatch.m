function B = labelBatch(runs, outDir, opts)
%LABELBATCH  A phone labelling batch from processed clips (Chris, 22 Nov, item 13; docs/design/LABELLING.md).
%   B = labelBatch(runs, 'out/batch1')
%   runs: a struct array of pipeline results (tv.pipeline.run or tools/quickLook), each with a
%   field .name (e.g. 'clip2'); the frames are read from each result's own files (res.rec).
%   Candidates, as the design's section 1 lists them (one detection, or a predicted position, in
%   one camera frame):
%     uncertain   the detector's score in the uncertain band round 0.5
%     lost        where a kept track ends, and where it would have gone two frames later
%     rejected    points the gate took out (by reason) and points of flights dropped as impossible
%     conflict    a confident spot (over 0.9) in one camera that no kept track or gate entry explains
%   Ranked by how unsure the model is x the source's weight (conflicts and losses highest) x how
%   rare the spot's place in the picture is among those already picked, then at most 5 from one
%   rally and the cameras alternated. Sized for opts.minutes of Chris's time (default 15) at
%   opts.secondsEach (default 7: a first batch, the full frame and the crop together, with the
%   frames round it).
%   Writes, per candidate (section 2 and 5 of the design): the full frame as JPEG 1920 px wide, the
%   256 x 256 crop from the full-resolution frame, and opts.neighbours frames either side (default
%   5) at 1280 px wide with their crops; and batch.json: every candidate's clip, camera, frame and
%   time, source, score, its place in the full frame (full-resolution px and in the 1920 picture),
%   the crop's origin, and the label fields left empty. The pictures are private (Tuesday's
%   footage): the batch stays in the private footage folder and goes to the phone privately.
if nargin < 3, opts = struct(); end
d = struct('minutes', 15, 'secondsEach', 7, 'neighbours', 5, 'perRally', 5, 'band', [0.15 0.85], 'fullWidth', 1920, ...
    'neighbourWidth', 1280, 'crop', 256, 'detector', 'round 5', 'seed', 1);
for f = fieldnames(d)', if ~isfield(opts, f{1}), opts.(f{1}) = d.(f{1}); end, end
if ~exist(outDir, 'dir'), mkdir(outDir); end
N = round(opts.minutes * 60 / opts.secondsEach);
C = gather(runs, opts);
B.n = 0;  B.candidates = C([]);  B.size = N;
if isempty(C), writeBatch(B, outDir, opts); return; end
% --- rank: uncertainty x source weight x rarity of the place in the picture (greedy) --------------
w = struct('conflict', 1.0, 'lost', 0.9, 'rejected', 0.7, 'uncertain', 0.6);
base = arrayfun(@(c) c.unsure * w.(c.source), C);
picked = false(size(C));  cellCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
perRally = containers.Map('KeyType', 'char', 'ValueType', 'double');
lastCam = 0;  order = [];
while numel(order) < N
    val = base;  val(picked) = -Inf;
    for i = find(~picked)
        key = cellKey(C(i));  if isKey(cellCount, key), val(i) = val(i) / sqrt(1 + cellCount(key)); end
        rk = rallyKey(C(i));  if isKey(perRally, rk) && perRally(rk) >= opts.perRally, val(i) = -Inf; end
        if C(i).cam == lastCam, val(i) = val(i) * 0.9; end           % alternate the cameras
    end
    [best, i] = max(val);
    if ~isfinite(best), break; end
    picked(i) = true;  order(end+1) = i; %#ok<AGROW>
    key = cellKey(C(i));  if isKey(cellCount, key), cellCount(key) = cellCount(key) + 1; else, cellCount(key) = 1; end
    rk = rallyKey(C(i));  if isKey(perRally, rk), perRally(rk) = perRally(rk) + 1; else, perRally(rk) = 1; end
    lastCam = C(i).cam;
end
C = C(order);
% --- pictures -------------------------------------------------------------------------------------------
for j = 1:numel(C)
    c = C(j);  info = runs(c.run).rec(c.cam);
    id = sprintf('%03d', j);
    k0 = max(0, c.frame - opts.neighbours);  k1 = min(info.nFrames - 1, c.frame + opts.neighbours);
    F = tv.media.readFrames(info, k0, k1 - k0 + 1);
    [H, W, ~, ~] = size(F);
    me = c.frame - k0 + 1;
    full = F(:, :, :, me);
    s = opts.fullWidth / W;
    imwrite(imresize(full, s), fullfile(outDir, [id '_full.jpg']), 'Quality', 88);
    [crop, o] = cropAt(full, c.uv, opts.crop);
    imwrite(crop, fullfile(outDir, [id '_crop.jpg']), 'Quality', 92);
    nb = struct('offset', {}, 'file', {}, 'cropFile', {}, 'cropOrigin', {});
    for q = 1:size(F, 4)
        if q == me, continue; end
        off = q - me;  uvq = c.uv + off * c.vel;          % the ring follows the predicted position
        nf = sprintf('%s_n%+d.jpg', id, off);  nc = sprintf('%s_n%+d_crop.jpg', id, off);
        imwrite(imresize(F(:, :, :, q), opts.neighbourWidth / W), fullfile(outDir, nf), 'Quality', 80);
        [cq, oq] = cropAt(F(:, :, :, q), uvq, opts.crop);
        imwrite(cq, fullfile(outDir, nc), 'Quality', 85);
        nb(end+1) = struct('offset', off, 'file', nf, 'cropFile', nc, 'cropOrigin', oq); %#ok<AGROW>
    end
    C(j).id = id;  C(j).fullFile = [id '_full.jpg'];  C(j).cropFile = [id '_crop.jpg'];  C(j).cropOrigin = o;
    C(j).uvFull = c.uv * s;  C(j).frameSize = [W H];  C(j).time = info.pts(c.frame + 1);  C(j).neighbours = nb;
end
B.n = numel(C);  B.candidates = C;
writeBatch(B, outDir, opts);
fprintf('label batch: %d candidates (%s) in %s\n', B.n, summary(C), outDir);
end

function C = gather(runs, opts)
% every candidate from every clip, with its source, uncertainty and the ball's motion per frame
C = struct('run', {}, 'clip', {}, 'cam', {}, 'rally', {}, 'frame', {}, 'uv', {}, 'vel', {}, 'source', {}, 'score', {}, 'unsure', {}, 'reason', {}, ...
    'id', {}, 'fullFile', {}, 'cropFile', {}, 'cropOrigin', {}, 'uvFull', {}, 'frameSize', {}, 'time', {}, 'neighbours', {});
for r = 1:numel(runs)
    res = runs(r);  nm = '';  if isfield(res, 'name'), nm = res.name; end
    nR = 0;  if isfield(res, 'candidates'), nR = size(res.candidates, 1); end
    for ra = 1:nR
        for k = 1:2
            cand = res.candidates{ra, k};
            tracks = struct('frames', {}, 'uv', {});
            if isfield(res, 'ballTracks') && ~isempty(res.ballTracks{ra, k}), tracks = res.ballTracks{ra, k}; end
            explained = zeros(0, 3);
            for t = tracks(:)', explained = [explained; t.frames(:), t.uv]; end %#ok<AGROW>
            % uncertain
            if ~isempty(cand) && size(cand, 2) >= 4
                s = cand(:, 4);
                for i = find(s >= opts.band(1) & s <= opts.band(2))'
                    C(end+1) = one(r, nm, k, ra, cand(i, 1), cand(i, 2:3), [0 0], 'uncertain', s(i), 1 - 2 * abs(s(i) - 0.5), ''); %#ok<AGROW>
                end
            end
            % lost: each kept track's end, and two frames further on
            for t = tracks(:)'
                if numel(t.frames) < 3, continue; end
                v = t.uv(end, :) - t.uv(end - 1, :);
                C(end+1) = one(r, nm, k, ra, t.frames(end), t.uv(end, :), v, 'lost', NaN, 0.8, 'track ends'); %#ok<AGROW>
                C(end+1) = one(r, nm, k, ra, t.frames(end) + 2, t.uv(end, :) + 2 * v, v, 'lost', NaN, 0.9, 'predicted after the track ends'); %#ok<AGROW>
            end
            % conflicts: a confident spot nothing explains
            if ~isempty(cand) && size(cand, 2) >= 4
                Lg = [];  if isfield(res, 'gateLog') && ~isempty(res.gateLog{ra}), Lg = res.gateLog{ra}([res.gateLog{ra}.cam] == k); end
                for i = find(cand(:, 4) > 0.9)'
                    f = cand(i, 1);  uv = cand(i, 2:3);
                    inT = any(explained(:, 1) == f & hypot(explained(:, 2) - uv(1), explained(:, 3) - uv(2)) < 4);
                    inG = ~isempty(Lg) && any([Lg.frame] == f & hypot([Lg.u] - uv(1), [Lg.v] - uv(2)) < 4);
                    if ~inT && ~inG, C(end+1) = one(r, nm, k, ra, f, uv, [0 0], 'conflict', cand(i, 4), 0.7, 'confident, in no kept track'); end %#ok<AGROW>
                end
            end
        end
        % rejected by the gate (one per track and reason, the middle one) and by the flight fit
        if isfield(res, 'gateLog') && ~isempty(res.gateLog{ra})
            Lg = res.gateLog{ra};
            keys = arrayfun(@(x) sprintf('%d|%d|%s', x.cam, x.track, x.reason), Lg, 'UniformOutput', false);
            [u, ~, g] = unique(keys);
            for q = 1:numel(u)
                sel = Lg(g == q);  m = sel(ceil(end / 2));
                C(end+1) = one(r, nm, m.cam, ra, m.frame, [m.u m.v], [0 0], 'rejected', NaN, 0.8, m.reason); %#ok<AGROW>
            end
        end
        if isfield(res, 'dropped') && numel(res.dropped) >= ra
            for g = res.dropped{ra}(:)'
                if ~isfield(g, 'obs') || isempty(g.obs), continue; end
                o = g.obs(ceil(end / 2), :);
                C(end+1) = one(r, nm, o(1), ra, o(2), o(3:4), [0 0], 'rejected', NaN, 0.85, 'flight dropped as impossible'); %#ok<AGROW>
            end
        end
    end
end
% inside the picture and the file only
keep = true(size(C));
for i = 1:numel(C)
    info = runs(C(i).run).rec(C(i).cam);
    keep(i) = C(i).frame >= 0 && C(i).frame < info.nFrames && all(isfinite(C(i).uv)) && ...
        C(i).uv(1) >= 1 && C(i).uv(2) >= 1 && C(i).uv(1) <= info.width && C(i).uv(2) <= info.height;
end
C = C(keep);
end

function c = one(r, nm, k, ra, frame, uv, vel, source, score, unsure, reason)
c = struct('run', r, 'clip', nm, 'cam', k, 'rally', ra, 'frame', round(frame), 'uv', uv(:)', 'vel', vel(:)', 'source', source, ...
    'score', score, 'unsure', unsure, 'reason', reason, 'id', '', 'fullFile', '', 'cropFile', '', 'cropOrigin', [0 0], ...
    'uvFull', [NaN NaN], 'frameSize', [0 0], 'time', NaN, 'neighbours', struct('offset', {}, 'file', {}, 'cropFile', {}, 'cropOrigin', {}));
end

function k = cellKey(c)
k = sprintf('%d|%d|%d', c.cam, min(3, floor(c.uv(1) / 1000)), min(3, floor(c.uv(2) / 560)));   % a 4 x 4 grid on a 4K picture
end

function k = rallyKey(c)
k = sprintf('%d|%d', c.run, c.rally);
end

function [crop, o] = cropAt(F, uv, s)
[H, W, ~] = size(F);
x0 = round(min(max(uv(1) - s / 2, 0), max(0, W - s)));  y0 = round(min(max(uv(2) - s / 2, 0), max(0, H - s)));
crop = F(y0 + 1:min(H, y0 + s), x0 + 1:min(W, x0 + s), :);
o = [x0 y0];
end

function writeBatch(B, outDir, opts)
L = struct('batch', datestr(now, 'yyyy-mm-dd HH:MM'), 'detector', opts.detector, 'size', B.size, 'n', B.n, ...
    'note', 'Label fields per docs/design/LABELLING.md section 8: action (yes, no, elsewhere, noBall, skip), x and y at full resolution for elsewhere, tag, device, labelledAt.', ...
    'candidates', {cell(1, B.n)});
for j = 1:B.n
    c = B.candidates(j);
    L.candidates{j} = struct('id', c.id, 'clip', c.clip, 'cam', c.cam, 'rally', c.rally, 'frame', c.frame, 'time', c.time, ...
        'source', c.source, 'reason', c.reason, 'score', c.score, 'x', c.uv(1), 'y', c.uv(2), 'frameSize', c.frameSize, ...
        'full', c.fullFile, 'xFull', c.uvFull(1), 'yFull', c.uvFull(2), 'crop', c.cropFile, 'cropOrigin', c.cropOrigin, ...
        'neighbours', c.neighbours, 'label', struct('action', '', 'x', [], 'y', [], 'tag', '', 'device', '', 'labelledAt', ''));
end
tv.util.writeJson(fullfile(outDir, 'batch.json'), L);
end

function t = summary(C)
s = {C.source};  u = unique(s);
t = strjoin(cellfun(@(x) sprintf('%s %d', x, nnz(strcmp(s, x))), u, 'UniformOutput', false), ', ');
end
