function [rows, all] = lookupTable(cfg)
%LOOKUPTABLE  Recommended camera placement for each side-fence distance.
%   Evaluates every combination of stand-off from the doubles sideline,
%   spot along the fence, height and lens aspect (tv.placement.evaluate),
%   then, for each fence distance in cfg.fenceDistances, picks:
%   1. On the fence, if any spot there meets every criterion: 16:9 before
%      4:3 (16:9 is the spec's starting mode), then the smallest far-corner
%      bounce error (to 0.1 cm), then the higher mount: height changes the
%      error by hundredths of a cm, and a higher camera sees over players,
%      which this check does not model.
%   2. A light stand between the fence and the court instead, when the fence
%      fails, or when its far-corner error is over
%      cfg.criteria.standIfErrorOverCm and a stand does better. Stands go in
%      the spec's band, 3-5 m outside the doubles sideline
%      (cfg.criteria.standBand), as far out as still works: farther is safer
%      for players chasing wide balls.
%   3. Otherwise nothing works; the row shows the best fence spot and why
%      it falls short.
%   ALL is every evaluated placement, for the full CSV.
c = tv.court.constants();
aspects = cellstr(cfg.aspects);
standoffs = unique([cfg.fenceDistances(:); cfg.standDistances(:)])';
xs = cfg.mountX.from : cfg.mountX.step : (c.halfLength + cfg.mountX.runBack + 1e-9);
pts = tv.court.playVolume(cfg.volume.behindBaseline, cfg.volume.maxHeight, cfg.volume.step);

all = [];
for a = 1:numel(aspects)
    lens = tv.lens.build(cfg.lenses, cfg.recommendLens, aspects{a});
    for s = standoffs
        for x = xs
            for h = cfg.heights(:)'
                r = tv.placement.evaluate(cfg, lens, s, x, h, pts);
                r.aspectRank = a;
                all = [all; r]; %#ok<AGROW>
            end
        end
    end
end

S   = [all.standoff];
ok  = [all.passes];
rows = [];
for d = cfg.fenceDistances(:)'
    onFence = find(S == d & ok);
    band    = cfg.criteria.standBand;
    stands  = find(S < d & S >= band(1) & S <= band(2) & ok);
    better  = stands([all(stands).errorCm] <= cfg.criteria.standIfErrorOverCm);
    if ~isempty(onFence)
        best = pick(onFence);  mount = 'fence';  why = '';
        if all(best).errorCm > cfg.criteria.standIfErrorOverCm && ~isempty(better)
            why  = sprintf('far-corner error on the fence is %.1f cm, over %g cm', ...
                           all(best).errorCm, cfg.criteria.standIfErrorOverCm);
            far  = max(S(better));
            best = pick(better(S(better) == far));  mount = 'light stand';
        end
    else
        why = whyNot(find(S == d));
        if ~isempty(stands)
            far  = max(S(stands));
            best = pick(stands(S(stands) == far));  mount = 'light stand';
        else
            cand = find(S == d);
            [~, k] = max([all(cand).coverage] * 1000 - [all(cand).errorCm]);
            best = cand(k);  mount = 'none';
        end
    end
    row = all(best);
    row.fence = d;  row.mount = mount;  row.whyNotFence = why;
    % Worst single-frame 3D error anywhere in the play volume, ball in the air
    % included (the weak spot of same-side cameras is along their own
    % sideline, where they look toward each other)
    lens = tv.lens.build(cfg.lenses, cfg.recommendLens, aspects{row.aspectRank});
    [row.worstVolumeErrorCm, w] = max(100 * tv.placement.stereoError(lens, row.cam1, row.cam2, pts, cfg.criteria.pixelSigma, 3));
    row.worstVolumePoint = pts(w, :);
    rows = [rows; row]; %#ok<AGROW>
end

    function k = pick(idx)
        key = [[all(idx).aspectRank]', round(10 * [all(idx).errorCm]'), -[all(idx).height]'];
        [~, order] = sortrows(key);
        k = idx(order(1));
    end

    function txt = whyNot(idx)
        % The first criterion that no fence spot can meet, in the order a
        % mounting decision would hit them.
        cr = cfg.criteria;  R = all(idx);
        full = R([R.coverage] >= 1);
        if isempty(full)
            txt = 'the court does not fit in the frame';
        elseif ~any([full.ballPx] >= cr.minBallPx)
            txt = sprintf('the ball is under %g px at the far corners', cr.minBallPx);
        elseif ~any([full.errorCm] <= cr.maxBounceErrorCm)
            txt = sprintf('far-corner error is over %g cm', cr.maxBounceErrorCm);
        else
            txt = 'no single spot meets every criterion at once';
        end
    end
end
