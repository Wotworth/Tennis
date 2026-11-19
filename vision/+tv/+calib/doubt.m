function D = doubt(report, widths, cfg)
%DOUBT  Which cameras' fitted poses should not be used without asking (TV-CAL-11, TV-CAL-21).
%   D = tv.calib.doubt(C.report, [rec.width], cfg): one entry per camera with
%     is      true when the fit is doubtful
%     reason  'lines': the court's own lines do not back the fit
%             'taps':  the tapped corners do not make a court from this camera
%     text    one sentence for the alert
%   A fit from the lines is doubtful when paint lies under less than cfg.minLineSupport of its
%   near-half lines (tv.calib.lineSupport), unless Chris has looked at the drawn fit and said
%   the lines are right (cfg.calibAccepted). A fit from tapped corners (tv.calib.fromCorners) is
%   taken on Chris's word: it is doubtful only when the taps could not be used, or miss the
%   fitted court's corners by more than cfg.maxTapRms of the picture's width.
D = struct('is', {}, 'reason', {}, 'text', {});
for k = 1:numel(report)
    r = report(k);
    d = struct('is', false, 'reason', '', 'text', '');
    if ~isempty(r.tapError)
        d.is = true;  d.reason = 'taps';
        d.text = sprintf('The tapped corners could not be used (%s) Tap the four corners of the doubles court again.', r.tapError);
    elseif strcmp(r.source, 'corners')
        lim = cfg.maxTapRms * widths(k);
        if r.tapRmsPx > lim
            d.is = true;  d.reason = 'taps';
            d.text = sprintf(['The four tapped corners miss a court''s corners by %.0f px (limit %.0f): ' ...
                'tap the four corners of the doubles court again.'], r.tapRmsPx, lim);
        end
    elseif r.support < cfg.minLineSupport && ~(numel(cfg.calibAccepted) >= k && cfg.calibAccepted(k))
        d.is = true;  d.reason = 'lines';
        d.text = sprintf(['Only %.0f%% of the court''s lines have paint under the fitted court (line error %.1f px), ' ...
            'so the camera position may be wrong.'], 100 * r.support, r.rmsPx);
    end
    D(k) = d;
end
end
