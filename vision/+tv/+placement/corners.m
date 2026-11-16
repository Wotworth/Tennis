function rows = corners(cfg)
%CORNERS  Layout 2: both cameras in the back-fence corners at the two ends, same side (Chris, 15 Nov).
%   For every back-fence distance (behind the baseline), side-fence distance
%   (outside the doubles sideline), height and lens mode in cfg.layout2, the
%   cameras sit at x = -/+(baseline + back), y = -(doubles sideline + side),
%   each aimed by tv.placement.aim (camera 2 the mirror image), and
%   tv.placement.evaluate measures it. Added here:
%     courtCrossDeg  smallest crossing angle over the court surface itself
%     worstAt        where on the court that is (x, y, m)
%     netCrossDeg    crossing angle at the net on the cameras' side, over the
%                    singles sideline, 1 m up (x = 0, y = -4.1)
%     netErrorCm     position error there, for 1 px in each camera
%     farRangeM      distance from the farther camera to the farthest corner
%     volWorst       where in the play volume the crossing angle is smallest
%   One row per (lens, aspect, back, side): the best height (smallest error).
%   PROVISIONAL like the rest of the check: published lens figures.
%   RETUNE(real lens): rerun with the calibrated lens (TV-CAL-01); check the
%   weak zone over the cameras' sideline at the net with bounce targets.
c = tv.court.constants();
L = cfg.layout2;
pts = tv.court.playVolume(cfg.volume.behindBaseline, cfg.volume.maxHeight, cfg.volume.step);
[gx, gy] = meshgrid(-c.halfLength:0.5:c.halfLength, -c.halfDoubles:0.5:c.halfDoubles);
court = [gx(:), gy(:), repmat(c.ballRadius, numel(gx), 1)];
lensNames = cellstr(L.lenses);  aspects = cellstr(cfg.aspects);
rows = [];
for li = 1:numel(lensNames)
    for a = 1:numel(aspects)
        lens = tv.lens.build(cfg.lenses, lensNames{li}, aspects{a});
        for back = L.backDistances(:)'
            for side = L.sideDistances(:)'
                best = [];
                for h = cfg.heights(:)'
                    r = tv.placement.evaluate(cfg, lens, side, c.halfLength + back, h, pts);
                    if isempty(best) || r.errorCm < best.errorCm, best = r; end
                end
                p1 = best.cam1.pos;  p2 = best.cam2.pos;
                [ang, i] = min(cross2(court, p1, p2));
                [~, j] = min(cross2(pts, p1, p2));
                row = struct('lens', lensNames{li}, 'aspect', aspects{a}, 'back', back, 'side', side, ...
                    'height', best.height, 'coverage', best.coverage, 'minCrossDeg', best.minCrossDeg, ...
                    'courtCrossDeg', ang, 'worstX', court(i, 1), 'worstY', court(i, 2), ...
                    'netCrossDeg', cross2([0, -c.halfSingles, 1], p1, p2), ...
                    'netErrorCm', 100 * tv.placement.stereoError(lens, best.cam1, best.cam2, [0, -c.halfSingles, 1], cfg.criteria.pixelSigma), ...
                    'farRangeM', max(vecnorm2([-c.halfLength, c.halfDoubles, 0] - p2), vecnorm2([c.halfLength, c.halfDoubles, 0] - p1)), ...
                    'volWorst', pts(j, :), 'ballPx', best.ballPx, 'errorCm', best.errorCm, 'passes', best.passes);
                rows = [rows; row]; %#ok<AGROW>
            end
        end
    end
end
end

function ang = cross2(P, p1, p2)
a = P - p1;  b = P - p2;
cosAng = sum(a .* b, 2) ./ (sqrt(sum(a.^2, 2)) .* sqrt(sum(b.^2, 2)));
ang = acosd(max(-1, min(1, cosAng)));
ang = min(ang, 180 - ang);
end

function n = vecnorm2(v)
n = sqrt(sum(v.^2, 2));
end
