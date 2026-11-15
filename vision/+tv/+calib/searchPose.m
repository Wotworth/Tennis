function [cam, report] = searchPose(bg, lens, opts)
%SEARCHPOSE  A camera's pose from the court lines alone, with no layout assumed (TV-CAL-10, 11).
%   Tries camera positions all round the court (outside the doubles court,
%   up to opts.maxRange metres from its centre, opts.heights high) and, at
%   each, a fan of aims around the court centre. Each trial is scored by a
%   two-way line match: how far the projected court lines fall from the
%   white line pixels, and how far the white line pixels fall from the
%   projected lines (so a pose that squeezes the whole court onto one line
%   scores badly). The best dozen are refined with tv.calib.courtPose; the
%   refined pose that matches the most line points, with line error under
%   1 px, wins.
%   Only half the positions are searched (y <= 0): the court's half-turn
%   symmetry makes the other half a mirror (tv.calib.rotate180); the twin is
%   resolved later with the second camera (tv.calib.resolveSymmetry).
%   Works for both of Chris's layouts (one side near each baseline; the
%   back-fence corners on one side) and anything in between.
%   RETUNE(real footage): search ranges, steps and the line caps.
if nargin < 3, opts = struct(); end
d = struct('xStep', 3, 'yStep', 2, 'maxRange', 27, 'heights', [2.5 3.5], ...
           'yawFan', -45:15:45, 'pitchFan', -12:6:12, 'cap', 12, 'keep', 24, 'nPixels', 250);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
c = tv.court.constants();
[mask, ~] = tv.calib.linePixels(bg);
D = bwdist(mask);
Mc = tv.calib.modelPoints(0.25);
[pr, pc] = find(mask);
tv.util.seed(1);
pick = randperm(numel(pr), min(opts.nPixels, numel(pr)));
pix = [pc(pick), pr(pick)];
% candidate positions
[gx, gy] = meshgrid(-24:opts.xStep:24, -18:opts.yStep:0);
pos2 = [gx(:), gy(:)];
outside = abs(pos2(:, 1)) > c.halfLength + 1 | abs(pos2(:, 2)) > c.halfDoubles + 1;
pos2 = pos2(outside & hypot(pos2(:, 1), pos2(:, 2)) <= opts.maxRange, :);
trials = zeros(0, 7);                  % x y z yaw pitch roll cost
for i = 1:size(pos2, 1)
    for h = opts.heights
        p = [pos2(i, :), h];
        yaw0 = atan2d(-p(2), -p(1));
        pitch0 = -atand(h / hypot(p(1), p(2)));
        for dy = opts.yawFan
            for dp = opts.pitchFan
                cam = tv.camera.make(lens, p, yaw0 + dy, pitch0 + dp, 0);
                trials(end+1, :) = [p, yaw0 + dy, pitch0 + dp, 0, score(cam)]; %#ok<AGROW>
            end
        end
    end
end
[~, o] = sort(trials(:, 7));
best = [];  bestCost = Inf;  report = struct();
tried = 0;  cands = zeros(0, 6);
for i = o(:)'
    t = trials(i, :);
    % skip near-duplicates of a start already refined
    if tried > 0 && any(vecnorm(starts(:, 1:3) - t(1:3), 2, 2) < 2.5 & abs(starts(:, 4) - t(4)) < 20), continue; end
    tried = tried + 1;  starts(tried, :) = t; %#ok<AGROW>
    cam0 = tv.camera.make(lens, t(1:3), t(4), t(5), t(6));
    [camR, rep] = tv.calib.courtPose(bg, cam0, struct('searchDeg', 3));
    % judge refined poses by the lines they truly match: matched points,
    % less a heavy penalty for line error above 1 px (TV-CAL-13)
    cst = -rep.inliers + 2000 * max(0, rep.rmsPx - 1) + 100 * score(camR);
    cands(end+1, :) = [camR.pos, rep.inliers, rep.rmsPx, cst]; %#ok<AGROW>
    if cst < bestCost, bestCost = cst; best = camR; report = rep; end
    if tried >= opts.keep, break; end
end
cam = best;
report.searchCost = bestCost;
report.candidates = cands;          % [x y z inliers rmsPx cost] per refined start
report.trials = size(trials, 1);

    function s = score(cm)
        [q, ok] = tv.camera.project(cm, Mc);
        a = opts.cap * ones(size(Mc, 1), 1);
        if any(ok), a(ok) = min(opts.cap, interp2(D, q(ok, 1), q(ok, 2), 'linear', opts.cap)); end
        b = opts.cap * ones(size(pix, 1), 1);
        if any(ok)
            Q = q(ok, :);
            d2 = (pix(:, 1) - Q(:, 1)').^2 + (pix(:, 2) - Q(:, 2)').^2;
            b = min(opts.cap, sqrt(min(d2, [], 2)));
        end
        s = mean(a) + mean(b);
    end
end
