function seg = fitSegment(obs, cams, rec, sync, air, prior, x0)
%FITSEGMENT  Fit one flight segment to both cameras' detections at once (TV-REC-01).
%   The flight model (gravity, drag, Magnus; tv.recon.segmentModel) is fitted
%   directly to the pixels each camera saw, at the time each camera saw
%   them (TV-SYNC-05: never by pairing frames). Least squares (lsqnonlin)
%   with a robust (Huber) reweighting, so a stray detection cannot drag the
%   path. The drag coefficient has a prior: N(prior.CD, prior.CDsd^2)
%   (TV-PHY-04). The lift has one too, centred on no spin: loose (sd
%   prior.CLsd, 0.25) for normal flights, tight (prior.shortCLsd, 0.05) for
%   flights shorter than prior.shortS (0.3 s). Too short a flight bends too
%   little to show its spin, and an unconstrained fit then invents spin to
%   soak up noise, which moves the bounce found from it (an 11 cm bounce
%   error on a 0.19 s flight after a bounce, 16 Nov).
%   obs rows: [cam frame u v]. x0: starting values (tv.recon.initSegment).
%   Returns seg: x, t0, rmsPx, n (detections per camera), obs, t, weights.
%   RETUNE(real footage): the Huber limit (2 px), the number of passes, and the
%   lift priors (0.25; 0.05 below 0.3 s), the 6 px outlier cut.
if nargin < 6 || isempty(prior), prior = struct('CD', 0.507, 'CDsd', 0.024); end
if ~isfield(prior, 'CLsd'), prior.CLsd = 0.25; end
if ~isfield(prior, 'shortS'), prior.shortS = 0.3; end
if ~isfield(prior, 'shortCLsd'), prior.shortCLsd = 0.05; end
if ~isfield(prior, 'rejectPx'), prior.rejectPx = 6; end
t = zeros(size(obs, 1), 1);
for k = 1:2
    i = obs(:, 1) == k;
    if any(i), t(i) = tv.recon.detTimes(k, obs(i, 2), obs(i, 4), rec, sync); end
end
if nargin < 7 || isempty(x0), [x0, ok] = tv.recon.initSegment(obs, t, cams, prior.CD); else, ok = true; end
seg = struct('x', [], 't0', min(t) - 0.001, 'rmsPx', Inf, 'n', [nnz(obs(:,1) == 1), nnz(obs(:,1) == 2)], ...
             'obs', obs, 't', t, 'w', [], 'ok', false);
if ~ok, return; end
t0 = seg.t0;
clSd = prior.CLsd;  if max(t) - min(t) < prior.shortS, clSd = prior.shortCLsd; end
w = ones(size(obs, 1), 1);
o = optimset('Display', 'off', 'MaxIter', 60, 'TolFun', 1e-9, 'TolX', 1e-9);
% physical limits: lift coefficient parts within +/-0.6, drag 0.3-0.8
lb = [-Inf -Inf -Inf -Inf -Inf -Inf -0.6 -0.6 0.3];
ub = [ Inf  Inf  Inf  Inf  Inf  Inf  0.6  0.6 0.8];
x = min(max(x0(:)', lb), ub);
if ~all(isfinite(residuals(x, w)))
    % a start from a neighbouring flight can be far off: start afresh
    [x, ok] = tv.recon.initSegment(obs, t, cams, prior.CD);
    if ~ok || ~all(isfinite(residuals(x, w))), return; end
end
try
    for pass = 1:3                                  % Huber reweighting
        x = lsqnonlin(@(x) residuals(x, w), x, lb, ub, o);
        x = x(:)';
        r = pixelErrors(x);
        w = min(1, 2 ./ max(r, eps));               % Huber, 2 px
    end
    % Huber still lets a far-off detection (another ball, a player's shoe)
    % pull with a constant force; a few of them moved a bounce 8 cm (16 Nov).
    % Drop detections more than prior.rejectPx (6 px) off the path and refit.
    far = r > prior.rejectPx;
    if any(far) && nnz(~far) >= 6
        w(far) = 0;
        x = lsqnonlin(@(x) residuals(x, w), x, lb, ub, o);
        x = x(:)';
    end
catch
    return                                          % seg.ok stays false
end
r = pixelErrors(x);
seg.x = x;  seg.w = w;  seg.ok = true;
seg.rmsPx = sqrt(mean(r(w > 0.5).^2));
seg.res = r;

    function res = residuals(x, w)
        [du, dv] = diffs(x);
        sw = sqrt(w);
        res = [du .* sw; dv .* sw; (x(9) - prior.CD) / prior.CDsd; x(7) / clSd; x(8) / clSd];
    end
    function r = pixelErrors(x)
        [du, dv] = diffs(x);
        r = hypot(du, dv);
    end
    function [du, dv] = diffs(x)
        P = tv.recon.segmentModel(x, t0, t, air);
        du = zeros(size(t));  dv = du;
        for kk = 1:2
            i = obs(:, 1) == kk;
            if ~any(i), continue; end
            px = tv.camera.project(cams(kk), P(i, :));
            du(i) = px(:, 1) - obs(i, 3);  dv(i) = px(:, 2) - obs(i, 4);
        end
    end
end
