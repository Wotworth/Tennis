function rows = scoreShots(S, segs, ev, air, cams)
%SCORESHOTS  Each synthetic shot against what the reconstruction found (fit study, error budget).
%   S: tv.synth.studySession; segs, ev: flights and events per rally; air, cams: what the
%   reconstruction used. A shot is found when a hit event lies within 30 ms of its truth.
%   Its metrics come from tv.metrics.shot, exactly as the pipeline computes them. Rows:
%   found, hitDtMs, speedErr (m/s), bounceErr (m), spinErr (m), netErr (m), rpmErrPct, call,
%   truthCall, shortAfterBounce, toNextHit, rms; curveErr (m, sideways curve from spin) and
%   curveTrue; setting (ball-machine setting, 0 for none); what was found (speedFound, spinFound,
%   curveFound, bounceFound) for the machine-consistency figures.
nR = numel(segs);
mcfg = struct('cams', cams, 'lines', 'singles');  info = struct('chris', 0);
rows = [];
for s = S.shots'
    row = struct('rally', s.rally, 'index', s.index, 'kind', s.kind, 'serve', s.isServe, 'truthCall', s.result, ...
        'shortAfterBounce', s.shortFlight, 'toNextHit', s.toNextHit, 'found', false, 'hitDtMs', NaN, ...
        'speedErr', NaN, 'bounceErr', NaN, 'spinErr', NaN, 'netErr', NaN, 'rpmErrPct', NaN, 'rpmKnownClPct', NaN, 'call', '', ...
        'bounceSegN', NaN, 'bounceSegS', NaN, 'rms', NaN, 'curveErr', NaN, 'curveTrue', NaN, 'setting', 0, ...
        'speedFound', NaN, 'spinFound', NaN, 'curveFound', NaN, 'bounceFound', [NaN NaN]);
    if isfield(s, 'spinCurve'), row.curveTrue = s.spinCurve; end
    if isfield(s, 'setting'), row.setting = s.setting; end
    E = ev{s.rally};  G = segs{s.rally};
    if isempty(E) || isempty(G), rows = [rows; row]; continue; end %#ok<AGROW>
    hits = E(strcmp({E.type}, 'hit'));
    [dt, i] = min(abs([hits.t] - s.tHit));
    if isempty(dt) || dt > 0.03, rows = [rows; row]; continue; end %#ok<AGROW>
    row.found = true;  row.hitDtMs = 1000 * (hits(i).t - s.tHit);
    hitEv = hits(i);
    seg = G(hitEv.segAfter);
    bEv = [];  nEv = [];  segAfter = [];
    b = E(strcmp({E.type}, 'bounce'));
    if ~isnan(s.tBounce) && ~isempty(b)
        [db, j] = min(abs([b.t] - s.tBounce));
        if db < 0.05, bEv = b(j); if bEv.segAfter > 0, segAfter = G(bEv.segAfter); end, end
    end
    nn = E(strcmp({E.type}, 'net'));
    if strcmp(s.result, 'net') && ~isempty(nn), nEv = nn(1); end
    m = tv.metrics.shot(seg, segAfter, hitEv, bEv, nEv, air, mcfg, [], info, s.isServe, sign(s.pHit(2)));
    row.speedErr = m.speedContact - s.speedHit;  row.speedFound = m.speedContact;
    row.rms = seg.rmsPx;
    if ~isempty(bEv)
        row.bounceErr = norm(m.bounce - s.pBounce(1:2));
        row.spinErr = m.spinEffect - s.spinEffect;
        if isfield(s, 'spinCurve'), row.curveErr = m.spinCurve - s.spinCurve; end
        row.spinFound = m.spinEffect;  row.curveFound = m.spinCurve;  row.bounceFound = m.bounce(1:2);
        if ~isempty(segAfter), row.bounceSegN = size(segAfter.obs, 1); row.bounceSegS = max(segAfter.t) - min(segAfter.t); end
    end
    if isfinite(s.netClearance) && isfinite(m.netClearance), row.netErr = m.netClearance - s.netClearance; end
    if isfinite(m.rpm) && s.rpm0 > 0, row.rpmErrPct = 100 * (m.rpm - s.rpm0) / s.rpm0; end
    % AC-11 reads "true C_L(S) known": score against the rpm the spec curve gives for the
    % shot's TRUE lift (its 15% scatter included), i.e. the lift measurement alone
    if isfinite(m.rpm) && isfield(s, 'CLnom') && s.CLnom > 0.03 && s.CL0 > 0.03
        ref = s.rpm0 * (s.CL0 - 0.03) / (s.CLnom - 0.03);
        row.rpmKnownClPct = 100 * (m.rpm - ref) / ref;
    end
    row.call = m.call;
    rows = [rows; row]; %#ok<AGROW>
end
end
