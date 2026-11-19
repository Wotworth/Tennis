function p = ballScores(net, pre, X, M)
%BALLSCORES  Ball probability per spot, cheaply: a first pass, then the classifier (TV-DET-04, round 4).
%   pre (tv.detect.loadBallNet of a *_pre.json file; [] for none) is a network about a tenth
%   the size looking at the middle 24 x 24 of each cut. A spot it scores under pre.threshold is
%   not a ball (0) and never reaches the classifier; the threshold was set so that 99.8% of the
%   ball examples pass. On busy footage about seven spots in eight stop there, and the frame takes
%   half the time with the same balls found (docs/reports/BALL-DETECTOR-1.md, round 4).
%   X, M: as tv.detect.ballNet, round 4 form (48-by-48 cuts at the ball's scale).
N = size(X, 5);
p = zeros(N, 1);
go = true(N, 1);
if ~isempty(pre)
    q = tv.detect.ballNet(pre, X(13:36, 13:36, :, :, :), M);
    go = q(:) >= pre.threshold;
end
if any(go), p(go) = tv.detect.ballNet(net, X(:, :, :, :, go), M(go, :)); end
end
