% Per-shot uncertainty of the spin effect and sideways curve (Chris, 21 Nov: show the curve tile only
% when the curve is clearly larger than that shot's own fitted uncertainty, and never a direction the
% fit isn't sure of). The fit's covariance (tv.recon.fitSegment, seg.cov) is propagated to both
% figures (tv.metrics.shot, the *SdFit fields); here it is checked against the scatter of repeated fits
% with fresh noise. The stated bands (spinEffectSd, spinCurveSd) add cfg.modelErr on top (21 Nov).

%% The predicted uncertainty matches the scatter over repeated fits
sc = tv.synth.defaultScenario();  cams = tv.synth.cameras(sc);
air = tv.physics.defaultParams();
rec = struct('pts', {(0:3000)' / sc.fps, (0:3000)' / sc.fps}, 'height', {540, 540});
sync = struct('startOffset', [0 0], 'delta', 0, 'drift', 0, 'tref', 0, 'readout', [0 0], 'shutter', 0);
x = [-11.5 -1 1.0, 24 2 5, 0.12 0.10 0.507];          % topspin and some sidespin
t0 = 100 / sc.fps;  frames = (100:190)';
tv.util.seed(5);
mcfg = struct('cams', cams, 'lines', 'singles');  info = struct('chris', 0);
truth = [];  got = zeros(0, 4);
for trial = 1:30
    obs = [];
    for k = 1:2
        P = tv.recon.segmentModel(x, t0, frames / sc.fps, air);
        px = tv.camera.project(cams(k), P) + 0.5 * randn(numel(frames), 2);
        obs = [obs; repmat(k, numel(frames), 1), frames, px]; %#ok<AGROW>
    end
    seg = tv.recon.fitSegment(obs, cams, rec, sync, air);
    assert(seg.ok && all(isfinite(seg.cov(:))))
    q = air;  q.CD = x(9);
    if isempty(truth)
        s0 = seg;  s0.x = x;
        b = struct('t', t0 + 1, 'p', [0 0 0]);
        m0 = tv.metrics.shot(s0, [], [], b, [], air, mcfg, [], info, false, -1);
        truth = [m0.spinEffect, m0.spinCurve];
    end
    m = tv.metrics.shot(seg, [], [], b, [], air, mcfg, [], info, false, -1);
    got(end+1, :) = [m.spinEffect, m.spinCurve, m.spinEffectSdFit, m.spinCurveSdFit]; %#ok<AGROW>
    assert(m.spinCurveSd >= m.spinCurveSdFit && m.spinEffectSd >= m.spinEffectSdFit)   % the stated bands add the model error
end
sdE = std(got(:, 1));  sdC = std(got(:, 2));
fprintf('spin effect: scatter %.1f cm, predicted %.1f cm (median)\n', 100 * sdE, 100 * median(got(:, 3)));
fprintf('curve:       scatter %.1f cm, predicted %.1f cm (median)\n', 100 * sdC, 100 * median(got(:, 4)));
assert(median(got(:, 4)) > sdC / 2 && median(got(:, 4)) < 2 * sdC)
assert(median(got(:, 3)) > sdE / 2 && median(got(:, 3)) < 2 * sdE)
inside = abs(got(:, 2) - truth(2)) < 2 * got(:, 4);
fprintf('curve within twice its own uncertainty: %d of %d\n', nnz(inside), numel(inside));
assert(nnz(inside) >= 0.8 * numel(inside))

%% "too close" counts as right only when the ball truly landed near the line (tv.synth.fairCall)
c = tv.court.constants();  hit = [-11 1 1];
assert(tv.synth.fairCall('in', 'in', [5 0 0], hit, false))
assert(tv.synth.fairCall('too close', 'in', [c.halfLength - 0.03, 0, 0], hit, false))     % 3 cm inside the baseline
assert(~tv.synth.fairCall('too close', 'in', [5 0 0], hit, false))                        % metres from any line
assert(~tv.synth.fairCall('out', 'in', [c.halfLength - 0.03, 0, 0], hit, false))
