function [tau, f, info] = readoutFromBands(prof, t, opts)
%READOUTFROMBANDS  Rolling-shutter readout time from a flickering lamp's bands (TV-SYNC-06).
%   A mains-powered lamp flickers at twice the mains frequency (120 Hz in
%   the US). With rolling shutter, row v of frame n is exposed at
%   t(n) + tau * (v - 1) / H, so the flicker shows as horizontal bands:
%       log I(n, v) = row(v) + frame(n) + B sin(2 pi f (t(n) + tau (v - 1) / H)) + ... (2nd harmonic)
%   prof: N-by-H row brightness (each frame averaged across its columns);
%   t: frame times (s, from the file, never n/fps). Every row gets its own
%   level (vignetting, the wall's shading) and every frame its own (exposure),
%   both removed exactly by centring the data and the model over rows and
%   frames. What is left is the bands' drift from frame to frame: at 119.88
%   fps a 120 Hz lamp drifts about one cycle in 8 s, so record about 10 s.
%   f and tau are fitted together: the band slope within a frame gives
%   f*tau, the drift gives f.
%   opts.fNominal (120) and opts.fRange (+/-0.5 Hz: the mains wanders by a
%   few hundredths of a hertz) keep f away from its aliases. opts.rowPos:
%   each column of prof's position as (row - 1) / height, when rows are binned.
%   Returns tau (s), f (Hz) and info.rmsResidual, info.contrast.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'fNominal'), opts.fNominal = 120; end
if ~isfield(opts, 'fRange'), opts.fRange = 0.5; end
[N, H] = size(prof);
q = centre(log(prof));                        % row and frame levels out
v = (0:H - 1) / H;
if isfield(opts, 'rowPos'), v = opts.rowPos(:)'; end   % binned rows: (centre row - 1) / height
t = t(:);
    function [r, coef] = resid(p)
        T = t + p(2) * v;                      % N-by-H exposure times
        ph = 2 * pi * p(1) * T;
        A = [col(sin(ph)), col(cos(ph)), col(sin(2 * ph)), col(cos(2 * ph))];
        coef = A \ q(:);
        r = q(:) - A * coef;
    end
% coarse grid, then refine
best = [Inf 0 0];
for ff = opts.fNominal + linspace(-opts.fRange, opts.fRange, 11)
    for tt = (1:1:40) / 1000
        e = sum(resid([ff tt]).^2);
        if e < best(1), best = [e ff tt]; end
    end
end
p = fminsearch(@(p) sum(resid([p(1), p(2) / 1000]).^2), [best(2), best(3) * 1000], ...
    optimset('TolX', 1e-9, 'TolFun', 1e-14, 'MaxFunEvals', 4000, 'MaxIter', 4000));
f = p(1);  tau = p(2) / 1000;
[r, coef] = resid([f tau]);
info.rmsResidual = sqrt(mean(r.^2));
info.contrast = hypot(coef(1), coef(2));
info.frames = N;  info.rows = H;
end

function c = col(X)
c = reshape(centre(X), [], 1);
end

function X = centre(X)
% remove each row's and each frame's mean (two-way: exact for additive levels)
X = X - mean(X, 1);  X = X - mean(X, 2);
end
