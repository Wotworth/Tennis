function [counts, names, lab] = trackLabels(tr, k, rec, cams, truth, tolPx)
%TRACKLABELS  Which synthetic ball each point of a 2D track really is (tests and diagnosis).
%   [counts, names, lab] = tv.synth.trackLabels(track, cam, rec, cams, truth, tolPx)
%   track: frames (0-based) and uv. Each point is matched to the nearest truth ball (Chris's, a
%   neighbour's, the crossing ball, the rolling stray) projected through the TRUE camera at the
%   moment that pixel row was exposed, within tolPx; else "none". counts(i): points of names{i}.
balls = {truth.ballP};  names = {'mine'};
if isfield(truth, 'others')
    for o = truth.others.balls(:)', balls{end+1} = o.ballP; names{end+1} = o.kind; end %#ok<AGROW>
end
names = [{'none'}, names];
cam = cams(k);  H = cam.height;
fr = tr.frames(:);  uv = tr.uv;
clock = cam.recordStart + rec(k).pts(fr + 1);
lab = zeros(numel(fr), 1);  best = inf(numel(fr), 1);
for b = 1:numel(balls)
    Tm = tv.synth.truthTime(cam, clock + cam.readout * (uv(:, 2) - 1) / H + cam.shutter / 2);
    Pb = tv.synth.ballAt(struct('T', truth.T, 'ballP', balls{b}), Tm);
    [px, ok] = tv.camera.project(cam, Pb);
    d = hypot(px(:, 1) - uv(:, 1), px(:, 2) - uv(:, 2));  d(~ok | any(isnan(Pb), 2)) = inf;
    better = d < best & d <= tolPx;
    lab(better) = b;  best(better) = d(better);
end
counts = arrayfun(@(b) nnz(lab == b), 0:numel(balls));
end
