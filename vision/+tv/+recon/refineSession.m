function [sync, air, segsByRally, report] = refineSession(segsByRally, cams, rec, sync, air, prior, opts)
%REFINESESSION  Camera timing and wind for the whole session, from every flight (TV-SYNC-03, TV-PHY-03).
%   Alternates: (1) refit every flight segment with the current timing and
%   air; (2) with the flights held, adjust the session parameters to shrink
%   every pixel error at once:
%     Delta, epsilon   camera 2's clock offset and drift (TV-SYNC-03)
%     readout(1:2)     each camera's rolling-shutter readout time
%     wind             horizontal wind, 2 numbers per 15-minute window,
%                      with a prior (half the 10 m forecast, sd 2 m/s,
%                      TV-PHY-04) and a penalty on changes between windows.
%   Then the session drag coefficient (TV-PHY-05) is the median of the
%   flights' fitted values, which becomes the next round's prior.
%   Indoors (opts.indoor) the wind stays 0 (TV-IND-01).
%   report: rounds of [Delta epsilon readout1 readout2 rmsPx].
%   RETUNE(real footage): the priors (readout from the mode's calibration +/- 1 ms, drift 0 +/- 100 ppm,
%   wind sd 2 m/s, 1 m/s between windows) and the number of rounds.
if nargin < 7, opts = struct(); end
d = struct('rounds', 3, 'windPrior', [0 0], 'windSd', 2, 'windStep', 1, 'windowS', 900, ...
           'indoor', false, 'readoutPrior', 0.008, 'readoutSd', 0.001, 'driftSd', 100e-6);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
segAll = vertcat(segsByRally{:});
if isempty(segAll), report = []; return; end
tAll = vertcat(segAll.t);
nW = floor((max(tAll) - min(tAll)) / opts.windowS) + 1;
t0w = min(tAll);
wind = repmat(opts.windPrior(:)', nW, 1);
if opts.indoor, wind(:) = 0; end
report = zeros(0, 5);
o = optimset('Display', 'off', 'MaxIter', 40, 'TolFun', 1e-10, 'TolX', 1e-10);
for round = 1:opts.rounds
    % (1) refit flights
    for r = 1:numel(segsByRally)
        for s = 1:numel(segsByRally{r})
            seg = segsByRally{r}(s);
            a = airAt(air, wind, seg.t0, t0w, opts.windowS);
            pr = prior;  if isfield(seg, 'anchors') && ~isempty(seg.anchors), pr.anchors = seg.anchors; end   % a one-camera flight keeps its pins
            f = tv.recon.fitSegment(seg.obs, cams, rec, sync, a, pr, seg.x);
            if f.ok, segsByRally{r}(s) = f; end
        end
    end
    segAll = vertcat(segsByRally{:});
    % (2) session parameters
    theta0 = [sync.delta, sync.drift * 1e6, sync.readout * 1000];
    if ~opts.indoor, theta0 = [theta0, reshape(wind', 1, [])]; end
    theta = lsqnonlin(@(th) res(th), theta0, [], [], o);
    theta = theta(:)';
    [sync, wind] = unpack(theta);
    rms = sqrt(mean(res(theta).^2));
    report(end+1, :) = [sync.delta, sync.drift, sync.readout, rms]; %#ok<AGROW>
    prior.CD = median(arrayfun(@(s) s.x(9), segAll));
end
air.windows = wind;  air.windowStart = t0w;  air.windowS = opts.windowS;
air.wind = wind(1, :);  air.wind(3) = 0;
air.sessionCD = prior.CD;

    function r = res(theta)
        [sy, wd] = unpack(theta(:)');
        r = [];
        for seg = segAll'
            tt = zeros(size(seg.obs, 1), 1);
            for kk = 1:2
                i = seg.obs(:, 1) == kk;
                if any(i), tt(i) = tv.recon.detTimes(kk, seg.obs(i, 2), seg.obs(i, 4), rec, sy); end
            end
            P = tv.recon.segmentModel(seg.x, seg.t0, tt, airAt(air, wd, seg.t0, t0w, opts.windowS));
            for kk = 1:2
                i = seg.obs(:, 1) == kk;
                if ~any(i), continue; end
                px = tv.camera.project(cams(kk), P(i, :));
                e = px - seg.obs(i, 3:4);
                w = sqrt(seg.w(i));
                r = [r; e(:, 1) .* w; e(:, 2) .* w]; %#ok<AGROW>
            end
        end
        r = [r; (sy.readout(:) - opts.readoutPrior) / opts.readoutSd; sy.drift / opts.driftSd];
        if ~opts.indoor
            r = [r; reshape((wd - opts.windPrior(1:2)) / opts.windSd, [], 1)];
            if size(wd, 1) > 1, r = [r; reshape(diff(wd) / opts.windStep, [], 1)]; end
        end
    end
    function [sy, wd] = unpack(th)
        sy = sync;  sy.delta = th(1);  sy.drift = th(2) / 1e6;  sy.readout = th(3:4) / 1000;
        if opts.indoor, wd = zeros(nW, 2); else, wd = reshape(th(5:end), 2, [])'; end
    end
end

function a = airAt(air, wind, t, t0w, windowS)
k = min(size(wind, 1), floor((t - t0w) / windowS) + 1);
a = air;  a.wind = [wind(max(k, 1), :), 0];
end
