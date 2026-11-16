function L = harvest(sessionId, result, opts)
%HARVEST  Auto-labels from one processed session (training data only; Chris, 15 Nov).
%   A frame is labelled only when the ball's position is trustworthy:
%     - it lies on a flight both cameras saw (each camera at least
%       opts.minPerCam detections) whose fit is physically possible and
%       tight (RMS under opts.maxRms px, drag and lift within limits);
%     - the label is the fitted flight's position at that frame's time:
%       detected frames and gaps alike (physics fills the gaps);
%     - frames where the ball is hidden are left out: inside a player's
%       box, or behind the net from that camera;
%     - frames in the hand-labelled test set are never labelled
%       (opts.exclude: their keys).
%   result: tv.pipeline.run's output (segs, cams, rec, sync, air, players).
%   Returns struct array: key, cam, frame, xy (pixels), kind ('detected' or 'gap').
if nargin < 3, opts = struct(); end
d = struct('minPerCam', 8, 'maxRms', 1.5, 'gapLimit', 6, 'exclude', {{}}, 'playerPad', 6, 'personBoxes', []);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
c = tv.court.constants();
L = struct('key', {}, 'cam', {}, 'frame', {}, 'xy', {}, 'kind', {});
for r = 1:numel(result.segs)
    for g = result.segs{r}(:)'
        if ~g.ok || g.rmsPx > opts.maxRms || any(g.n < opts.minPerCam), continue; end
        if g.x(9) < 0.3 || g.x(9) > 0.8 || hypot(g.x(7), g.x(8)) > 0.6, continue; end   % not physical
        for k = 1:2
            seen = sort(g.obs(g.obs(:, 1) == k, 2));
            if isempty(seen), continue; end
            for fr = seen(1):seen(end)
                % gaps: only short ones, bridged by the flight model
                isDet = any(seen == fr);
                if ~isDet && min(abs(seen - fr)) > opts.gapLimit, continue; end
                key = sprintf('%s|%s', sessionId, tv.learn.frameRef(k, fr));
                if any(strcmp(opts.exclude, key)), continue; end
                cam = result.cams(k);
                v = cam.height / 2;   % rolling shutter: two passes for the row
                for it = 1:2
                    t = tv.recon.detTimes(k, fr, v, result.rec, result.sync);
                    P = tv.recon.segmentModel(g.x, g.t0, t, result.air);
                    [px, ok] = tv.camera.project(cam, P);
                    if ~ok, break; end
                    v = px(2);
                end
                if ~ok, continue; end
                if behindNet(cam, P, c) || inPlayer(opts.personBoxes, k, fr, px, opts.playerPad), continue; end
                L(end+1) = struct('key', key, 'cam', k, 'frame', fr, 'xy', px, 'kind', ifelse(isDet, 'detected', 'gap')); %#ok<AGROW>
            end
        end
    end
end
end

function tf = behindNet(cam, P, c)
% does the sight line from the camera to the ball pass through the net?
tf = false;
if sign(cam.pos(1)) == sign(P(1)) || P(1) == 0, return; end
s = cam.pos(1) / (cam.pos(1) - P(1));
q = cam.pos + s * (P - cam.pos);
tf = abs(q(2)) <= c.postY && q(3) >= 0 && q(3) <= tv.court.netHeight(q(2));
end

function tf = inPlayer(boxes, cam, frame, px, pad)
% boxes: rows [cam frame x y w h] of people the pipeline saw
tf = false;
if isempty(boxes), return; end
b = boxes(boxes(:, 1) == cam & abs(boxes(:, 2) - frame) <= 2, 3:6);
for i = 1:size(b, 1)
    if px(1) >= b(i, 1) - pad && px(1) <= b(i, 1) + b(i, 3) + pad && px(2) >= b(i, 2) - pad && px(2) <= b(i, 2) + b(i, 4) + pad
        tf = true; return
    end
end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
