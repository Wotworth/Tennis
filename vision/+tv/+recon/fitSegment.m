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
%   Returns seg: x, t0, rmsPx, n (detections per camera), obs, t, weights, and cov: the 9-by-9
%   covariance of x from the fit itself (pixel noise at the fit's own error, the priors), for the
%   per-shot uncertainty of what is shown (Chris, 21 Nov: the curve tile only when the curve is
%   clearly larger than its own uncertainty). Wind gusts and timing are not in it.
%   One camera only (Chris, 18 Nov): when the other camera is blocked for a whole flight, one
%   camera's sight lines and the physics still give the path, but its distance from the camera
%   only weakly. prior.anchors pins it: rows [t x y z sd], points the flight must pass at
%   those times (where the neighbouring flight ended or began; on the ground at a bounce),
%   each to within sd metres. Without x0 the start then comes from tv.recon.initOneCam.
%   seg.oneCam says only one camera saw it; seg.anchors keeps the pins for later refits.
%   RETUNE(real footage): the Huber limit (2 px), the number of passes, and the
%   lift priors (0.25; 0.05 below 0.3 s), the 6 px outlier cut (at most 10% of a flight).
if nargin < 6 || isempty(prior), prior = struct('CD', 0.507, 'CDsd', 0.024); end
if ~isfield(prior, 'CLsd'), prior.CLsd = 0.25; end
if ~isfield(prior, 'shortS'), prior.shortS = 0.3; end
if ~isfield(prior, 'shortCLsd'), prior.shortCLsd = 0.05; end
if ~isfield(prior, 'rejectPx'), prior.rejectPx = 6; end
if ~isfield(prior, 'rejectMaxFrac'), prior.rejectMaxFrac = 0.1; end
if ~isfield(prior, 'anchors'), prior.anchors = zeros(0, 5); end
A = prior.anchors;
n12 = [nnz(obs(:, 1) == 1), nnz(obs(:, 1) == 2)];
oneCam = min(n12) < 3;                              % too few from one camera to triangulate with
[~, kMain] = max(n12);  iMain = obs(:, 1) == kMain;
t = zeros(size(obs, 1), 1);
for k = 1:2
    i = obs(:, 1) == k;
    if any(i), t(i) = tv.recon.detTimes(k, obs(i, 2), obs(i, 4), rec, sync); end
end
t0 = min([t; A(:, 1)]) - 0.001;                      % the flight starts no later than its first pin
if nargin < 7 || isempty(x0)
    if oneCam, [x0, ok] = tv.recon.initOneCam(obs(iMain, :), t(iMain), cams, A, air, prior.CD);
    else, [x0, ok] = tv.recon.initSegment(obs, t, cams, prior.CD); end
else, ok = true;
end
seg = struct('x', [], 't0', t0, 'rmsPx', Inf, 'n', [nnz(obs(:,1) == 1), nnz(obs(:,1) == 2)], ...
             'obs', obs, 't', t, 'w', [], 'ok', false, 'oneCam', oneCam, 'anchors', A, 'res', [], 'cov', NaN(9));
if ~ok, return; end
clSd = prior.CLsd;  if max(t) - min(t) < prior.shortS, clSd = prior.shortCLsd; end
w = ones(size(obs, 1), 1);
o = optimset('Display', 'off', 'MaxIter', 60, 'TolFun', 1e-9, 'TolX', 1e-9);
% physical limits: lift coefficient parts within +/-0.6, drag 0.3-0.8
lb = [-Inf -Inf -Inf -Inf -Inf -Inf -0.6 -0.6 0.3];
ub = [ Inf  Inf  Inf  Inf  Inf  Inf  0.6  0.6 0.8];
x = min(max(x0(:)', lb), ub);
if ~all(isfinite(residuals(x, w)))
    % a start from a neighbouring flight can be far off: start afresh
    if oneCam, [x, ok] = tv.recon.initOneCam(obs(iMain, :), t(iMain), cams, A, air, prior.CD);
    else, [x, ok] = tv.recon.initSegment(obs, t, cams, prior.CD); end
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
    % Only a few strays: if many detections are far off, the flight is the wrong
    % model (it spans a hit or a bounce) and must show a large error, so the
    % merge and split tests see it.
    far = r > prior.rejectPx;
    if any(far) && nnz(far) <= prior.rejectMaxFrac * numel(far) && nnz(~far) >= 6
        w(far) = 0;
        x = lsqnonlin(@(x) residuals(x, w), x, lb, ub, o);
        x = x(:)';
    end
catch
    return                                          % seg.ok stays false
end
r = pixelErrors(x);
seg.x = x;  seg.w = w;  seg.ok = true;
seg.rmsPx = sqrt(mean(r(w > 0).^2));             % every detection kept (Huber-weighted ones too)
seg.res = r;
seg.cov = covariance(x, w);

    function C = covariance(x, w)
        % Gauss-Newton: J'J of the residuals with the pixel rows scaled by the fit's own pixel
        % error (at least 0.3 px), the prior rows as they are (already in sd units)
        nPix = 2 * numel(t);
        r0 = residuals(x, w);
        J = zeros(numel(r0), 9);
        for j = 1:9
            h = 1e-6 * max(1, abs(x(j)));
            xp = x;  xp(j) = xp(j) + h;
            J(:, j) = (residuals(xp, w) - r0) / h;
        end
        keep = [w > 0; w > 0];
        sPx = max(0.3, sqrt(sum(r0([keep; false(numel(r0) - nPix, 1)]).^2) / max(1, nnz(keep) - 9)));
        J(1:nPix, :) = J(1:nPix, :) / sPx;
        C = pinv(J' * J);
    end
    function res = residuals(x, w)
        [du, dv, da] = diffs(x);
        sw = sqrt(w);
        res = [du .* sw; dv .* sw; (x(9) - prior.CD) / prior.CDsd; x(7) / clSd; x(8) / clSd; da(:)];
    end
    function r = pixelErrors(x)
        [du, dv] = diffs(x);
        r = hypot(du, dv);
    end
    function [du, dv, da] = diffs(x)
        P = tv.recon.segmentModel(x, t0, [t; A(:, 1)], air);
        % pins, weighted so that sd metres off costs as much as one pixel
        da = (P(numel(t) + 1:end, :) - A(:, 2:4)) ./ A(:, 5);
        P = P(1:numel(t), :);
        du = zeros(size(t));  dv = du;
        for kk = 1:2
            i = obs(:, 1) == kk;
            if ~any(i), continue; end
            px = tv.camera.project(cams(kk), P(i, :));
            du(i) = px(:, 1) - obs(i, 3);  dv(i) = px(:, 2) - obs(i, 4);
        end
    end
end
