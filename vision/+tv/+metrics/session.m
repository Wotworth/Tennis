function S = session(shots, rallies, air)
%SESSION  Per-session summary by shot type (TV-MET-02) and per-rally figures (TV-MET-01).
%   shots: struct array from tv.metrics.shot, with .rally. Medians and the
%   spread (interquartile range) of speed, spin effect, rpm, net clearance
%   and depth; in %; the landing-spot dispersion ellipse (1-sigma area,
%   m^2); first-serve speed and in %; and per-rally medians over time
%   (the fatigue curve).
cd = NaN;  if isfield(air, 'sessionCD'), cd = air.sessionCD; end
S.air = struct('rho', air.rho, 'wind', air.wind, 'sessionCD', cd);
if isempty(shots)                                     % no shots (an empty-court clip, one drop: 22 Nov)
    S.byType = struct();  S.firstServe = struct('speed', stats([]), 'inPct', NaN);
    S.rallies = rallies;  S.overTime = struct('rally', {}, 't', {}, 'speed', {}, 'spinEffect', {});
    return
end
types = unique({shots.type});
S.byType = struct();
for k = 1:numel(types)
    sh = shots(strcmp({shots.type}, types{k}));
    t.count = numel(sh);
    t.speed = stats([sh.speedContact]);
    t.spinEffect = stats([sh.spinEffect]);
    t.rpm = stats([sh.rpm]);
    t.netClearance = stats([sh.netClearance]);
    t.depth = stats([sh.depth]);
    called = sh(ismember({sh.call}, {'in', 'out', 'net', 'too close'}));
    t.inPct = 100 * mean(strcmp({called.call}, 'in'));
    B = reshape([sh.bounce], 2, [])';  B = B(all(isfinite(B), 2), :);
    t.ellipseArea = NaN;
    if size(B, 1) >= 3, t.ellipseArea = pi * sqrt(det(cov(B))); end
    S.byType.(types{k}) = t;
end
serves = shots([shots.isServe]);
S.firstServe.speed = stats([serves.speedContact]);
S.firstServe.inPct = 100 * mean(strcmp({serves.call}, 'in'));
S.rallies = rallies;
r = [shots.rally];
S.overTime = arrayfun(@(k) struct('rally', k, 't', min([shots(r == k).t]), ...
    'speed', median([shots(r == k).speedContact]), 'spinEffect', median([shots(r == k).spinEffect], 'omitnan')), unique(r));
end

function s = stats(v)
v = v(isfinite(v));
if isempty(v), s = struct('median', NaN, 'iqr', NaN, 'n', 0); return; end
q = sort(v);  n = numel(q);
p = @(f) interp1(linspace(0, 1, n), q, f);
if n == 1, s = struct('median', q, 'iqr', 0, 'n', 1); return; end
s = struct('median', median(q), 'iqr', p(0.75) - p(0.25), 'n', n);
end
