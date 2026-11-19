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
%   [19 Nov, first real pictures through this routine] Matched points alone picked a court one
%   doubles alley sideways on a real hard court (lines of the shifted court lie on other real
%   lines, so many points match). The winner is now judged line by line (tv.calib.lineSupport:
%   the share of each near-half line that has paint under it; a shifted court leaves a sideline
%   over bare court); among the well-supported poses the one matching the most points wins. The
%   one-camera routine's pose (tv.calib.courtFromLines, from the lines' crossings) joins the
%   candidates where it finds one. When no refined pose is well supported, the best few are also
%   tried moved by the court's own look-alike shifts (an alley or a singles half-width sideways,
%   a service box lengthways) and refined again.
%   Only half the positions are searched (y <= 0): the court's half-turn
%   symmetry makes the other half a mirror (tv.calib.rotate180); the twin is
%   resolved later with the second camera (tv.calib.resolveSymmetry).
%   Works for both of Chris's layouts (one side near each baseline; the
%   back-fence corners on one side) and anything in between.
%   RETUNE(real footage): search ranges, steps and the line caps.
if nargin < 3, opts = struct(); end
d = struct('xStep', 3, 'yStep', 2, 'maxRange', 27, 'heights', [2.5 3.5], ...
           'yawFan', -45:15:45, 'pitchFan', -12:6:12, 'rollFan', 0, 'cap', 12, 'keep', 24, 'nPixels', 250, ...
           'xGrid', -24:3:24, 'yGrid', -18:2:0, 'supportOk', 0.85, 'supportTie', 0.1, 'hopFrom', 3, 'crossings', true);
% rollFan: a hand-mounted phone is not level (first real footage, 17 Nov); xGrid/yGrid narrow
% or refine the positions tried (defaults: xStep/yStep over the whole surround)
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
c = tv.court.constants();
if ~isfield(opts, 'lineOpts'), opts.lineOpts = struct(); end
[mask, ~] = tv.calib.linePixels(bg, opts.lineOpts);   % lineOpts: real-footage line settings (tv.calib.linePixels)
D = bwdist(mask);
Mc = tv.calib.modelPoints(0.25);
[pr, pc] = find(mask);
tv.util.seed(1);
pick = randperm(numel(pr), min(opts.nPixels, numel(pr)));
pix = [pc(pick), pr(pick)];
% candidate positions
if isequal(opts.xGrid, -24:3:24) && opts.xStep ~= 3, opts.xGrid = -24:opts.xStep:24; end
if isequal(opts.yGrid, -18:2:0) && opts.yStep ~= 2, opts.yGrid = -18:opts.yStep:0; end
[gx, gy] = meshgrid(opts.xGrid, opts.yGrid);
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
                for dr = opts.rollFan
                    cam = tv.camera.make(lens, p, yaw0 + dy, pitch0 + dp, dr);
                    trials(end+1, :) = [p, yaw0 + dy, pitch0 + dp, dr, score(cam)]; %#ok<AGROW>
                end
            end
        end
    end
end
[~, o] = sort(trials(:, 7));
tried = 0;  cands = zeros(0, 7);  camsR = {};  reps = {};
for i = o(:)'
    t = trials(i, :);
    % skip near-duplicates of a start already refined
    if tried > 0 && any(vecnorm(starts(:, 1:3) - t(1:3), 2, 2) < 2.5 & abs(starts(:, 4) - t(4)) < 20), continue; end
    tried = tried + 1;  starts(tried, :) = t; %#ok<AGROW>
    refine(tv.camera.make(lens, t(1:3), t(4), t(5), t(6)));
    if tried >= opts.keep, break; end
end
% where the view runs along the court, the lines' own crossings give a pose directly
% (tv.calib.courtFromLines, the one-camera routine); it is refined and judged with the rest. On
% a clay court seen from behind the baseline the grid search above found no start that
% converged (19 Nov); from beside the court it finds no pattern and adds nothing.
% opts.crossings = false leaves it out (to check this routine by itself against that one).
if opts.crossings
    try
        refine(tv.calib.courtFromLines(bg, lens, struct('lineOpts', opts.lineOpts)));
    catch err
        if ~strcmp(err.identifier, 'tv:calib:noCourt'), rethrow(err); end
    end
end
% look-alike shifts: a court moved by one of its own line spacings puts most lines on other
% lines. Seen from the camera that is the camera moved the other way, aim unchanged.
if max(cands(:, 7)) < opts.supportOk
    [~, oc] = sort(cands(:, 7), 'descend');
    hops = [0 c.halfDoubles - c.halfSingles; 0 c.halfSingles; c.halfLength - c.serviceLine 0];
    hops = [hops; -hops];
    for i = oc(1:min(opts.hopFrom, numel(oc)))'
        for h = 1:size(hops, 1)
            cm = camsR{i};  cm.pos(1:2) = cm.pos(1:2) + hops(h, :);
            if cm.pos(2) > 1, continue; end        % only the searched half; the twin is resolved later
            refine(cm);
        end
    end
end
% the winner: among the poses whose line-by-line support is within supportTie of the best, the one
% that matches the most line points (a pose that sees little of the court can have every line it
% sees on paint; the true pose explains more of the picture)
key = cands(:, 7);
tie = find(key >= max(key) - opts.supportTie);
[~, j] = max(cands(tie, 4));  j = tie(j);
cam = camsR{j};  report = reps{j};
report.support = cands(j, 7);
report.searchCost = cands(j, 6);
report.candidates = cands;          % [x y z inliers rmsPx cost support] per refined start
report.trials = size(trials, 1);

    function refine(cam0)
        [camR, rep] = tv.calib.courtPose(bg, cam0, struct('searchDeg', 3, 'lineOpts', opts.lineOpts));
        % matched points, less a heavy penalty for line error above 1 px (TV-CAL-13)
        cst = -rep.inliers + 2000 * max(0, rep.rmsPx - 1) + 100 * score(camR);
        [sup, per] = tv.calib.lineSupport(camR, mask);
        if size(per, 1) < 3, sup = 0; end             % fewer than three lines in view prove nothing
        sup = sup - 0.25 * max(0, rep.rmsPx - 1);
        % outside the search's own range a pose proves nothing either: a camera far away squeezes
        % the whole court onto a few line pixels and matches everything (seen 19 Nov, 85 m off)
        if hypot(camR.pos(1), camR.pos(2)) > opts.maxRange + 5 || camR.pos(3) < 1 || camR.pos(3) > 10, sup = -1; end
        cands(end+1, :) = [camR.pos, rep.inliers, rep.rmsPx, cst, sup];
        camsR{end+1} = camR;  reps{end+1} = rep;
    end

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
