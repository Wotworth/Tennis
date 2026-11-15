function [cams, report] = resolveSymmetry(cands, tracksByCam, rec, sync, people)
%RESOLVESYMMETRY  Pick each camera's pose or its half-turn twin, so both cameras agree.
%   Each camera's pose from the lines has a twin (tv.calib.rotate180) that
%   sees the same picture. Of the four combinations, the right ones are those
%   where the two cameras agree on where things are:
%     ball:    sight lines to the ball from both cameras meet (median gap,
%              at the best clock offset: tv.sync.fromRays)
%     players: each person's court position from camera 1 matches one from
%              camera 2 (median distance)
%   Two combinations always agree equally (the whole pair turned half a
%   turn); the court frame's convention picks between them: the cameras'
%   side is y < 0 (TV-ARCH-10). If camera 2 then sits at the lower x, the
%   report says so: x then points toward camera 1's end.
%   cands(k): camera k's pose from tv.calib.searchPose. people: struct array
%   (t, dets1, dets2) of person detections (box bottoms in pixels) at a few
%   moments, or [] to judge by the ball alone.
opts = {cands(1), tv.calib.rotate180(cands(1)); cands(2), tv.calib.rotate180(cands(2))};
combos = [1 1; 1 2; 2 1; 2 2];
report.ballGap = nan(4, 1);  report.playerGap = nan(4, 1);  report.delta = nan(4, 1);
for c = 1:4
    cc = [opts{1, combos(c, 1)}, opts{2, combos(c, 2)}];
    [report.delta(c), curve] = tv.sync.fromRays(tracksByCam, cc, rec, sync, 60);
    report.ballGap(c) = min(curve);
    if ~isempty(people), report.playerGap(c) = playerGap(cc, people); end
end
% rank by the ball when it was seen, by the players otherwise
score = report.ballGap;
if all(isnan(score)), score = report.playerGap; end
pg = report.playerGap;  pg(isnan(pg)) = 0;
score = score + 0.01 * pg;
[~, best] = min(score);
cams = [opts{1, combos(best, 1)}, opts{2, combos(best, 2)}];
report.chosen = combos(best, :);
% the court frame's convention: cameras on the y < 0 side
if mean([cams.pos] * kron(eye(2), [0; 1; 0]) * [1; 1] / 2) > 0
    cams = [tv.calib.rotate180(cams(1)), tv.calib.rotate180(cams(2))];
end
report.delta = report.delta(best);
report.cam2AtLowerX = cams(2).pos(1) < cams(1).pos(1);
end

function g = playerGap(cams, people)
gaps = [];
for s = people(:)'
    P1 = ground(cams(1), s.dets1);  P2 = ground(cams(2), s.dets2);
    if isempty(P1) || isempty(P2), continue; end
    for i = 1:size(P1, 1)
        gaps(end+1) = min(sqrt(sum((P2 - P1(i, :)).^2, 2))); %#ok<AGROW>
    end
end
g = NaN;  if ~isempty(gaps), g = median(gaps); end
end

function P = ground(cam, feet)
% court positions of box-bottom pixels
P = zeros(0, 2);
if isempty(feet), return; end
D = tv.camera.rays(cam, feet);
for i = 1:size(D, 1)
    if D(i, 3) >= 0, continue; end
    q = cam.pos + (-cam.pos(3) / D(i, 3)) * D(i, :);
    P(end+1, :) = q(1:2); %#ok<AGROW>
end
end
