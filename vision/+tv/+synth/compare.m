function rep = compare(result, truth, cams, sc)
%COMPARE  How close the pipeline came to a synthetic session's known answers (TV-TST-01).
%   Every figure here is checked against the acceptance targets in
%   tests/pipelineTest.m.
%   cameraPosM, cameraRotDeg   pose from the court lines vs truth
%   syncErrMs                  camera 2 timing error at mid-session (AC-05)
%   rallyCapture               share of true shots inside a found rally (AC-03)
%   shotsFound/shotsTrue       shots matched by time (within 30 ms)
%   speedErr                   |speed at contact| error, m/s (AC-07: 2 mph = 0.89 m/s)
%   bounceErr                  bounce position error, m (AC-08)
%   spinEffectErr              spin effect error, m (AC-10)
%   hitterOk                   share of shots credited to the right player (AC-13)
%   calls                      in/out/net calls that match
for k = 1:2
    rep.cameraPosM(k) = norm(result.cams(k).pos - cams(k).pos);
    rep.cameraRotDeg(k) = acosd(min(1, (trace(result.cams(k).R * cams(k).R') - 1) / 2));
end
% timing: the session time of camera 2's middle frame vs the truth for it
r2 = result.rec(2);  n = round(r2.nFrames / 2);
% judged at the middle row, where the ball mostly is (offset and readout trade off across rows)
vMid = r2.height / 2;
tPipe = tv.recon.detTimes(2, n, vMid, result.rec, result.sync) - result.sync.shutter / 2;
clock2 = cams(2).recordStart + r2.pts(n + 1) + cams(2).readout * (vMid - 1) / r2.height;
tTrue = tv.synth.truthTime(cams(2), clock2);
% session time 0 = camera 1's first frame = truth time cams(1).recordStart
rep.syncErrMs = 1000 * (tPipe - (tTrue - tv.synth.truthTime(cams(1), cams(1).recordStart)));
rep.readoutErrMs = 1000 * (result.sync.readout - [cams.readout]);
ts = [truth.shots.tHit];
W = result.rallyWindows;
rep.rallyCapture = mean(arrayfun(@(t) any(t >= W(:, 1) & t <= W(:, 2)), ts));
rep.shotsTrue = numel(truth.shots);
rep.shotsFound = 0;
rep.missing = [];  rep.calls = {};
rep.speedErr = [];  rep.bounceErr = [];  rep.spinEffectErr = [];  rep.hitterOk = [];  rep.callOk = [];
names = {sc.players.name};
for s = truth.shots'
    if isempty(result.shots), break; end
    [dt, i] = min(abs([result.shots.t] - s.tHit));
    if dt > 0.03, rep.missing(end+1) = s.tHit; continue; end
    m = result.shots(i);
    rep.shotsFound = rep.shotsFound + 1;
    rep.speedErr(end+1) = abs(m.speedContact - s.speedHit);
    if ~any(isnan(s.pBounce)) && all(isfinite(m.bounce))
        rep.bounceErr(end+1) = norm(m.bounce - s.pBounce(1:2));
        rep.spinEffectErr(end+1) = abs(m.spinEffect - s.spinEffect);
    end
    want = names{s.hitter};
    got = m.hitter;  if ~strcmp(got, 'Chris') && ~strcmp(got, 'unknown'), got = 'Opponent'; end
    rep.hitterOk(end+1) = strcmp(got, want);
    rep.callOk(end+1) = tv.synth.fairCall(m.call, s.result, s.pBounce, s.pHit, s.isServe);   % "too close" is right only near a line (21 Nov)
    rep.calls{end+1} = sprintf('%.2f %s->%s', s.tHit, s.result, m.call);
end
end
