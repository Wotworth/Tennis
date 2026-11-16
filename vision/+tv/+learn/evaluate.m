function m = evaluate(detectFn, T, frames, opts)
%EVALUATE  A detector's recall and precision on the hand-labelled test set.
%   detectFn(F) returns candidates [u v score] for one frame image F (the
%   detector's best guess first). frames(key) gives that test frame's image
%   (a containers.Map, or a function handle key -> image).
%   A frame with a ball counts as found when the best candidate is within
%   opts.radius pixels of the true position (recall = found / with ball).
%   Precision = correct detections / all detections, where a detection on a
%   "no ball" frame, or far from the ball, is wrong.
if nargin < 4, opts = struct(); end
if ~isfield(opts, 'radius'), opts.radius = 6; end
found = 0;  withBall = 0;  correct = 0;  said = 0;
for t = T(:)'
    if isa(frames, 'function_handle'), F = frames(t.key); else, F = frames(t.key); end
    C = detectFn(F);
    if t.hasBall, withBall = withBall + 1; end
    if isempty(C), continue; end
    said = said + 1;
    if t.hasBall && hypot(C(1, 1) - t.xy(1), C(1, 2) - t.xy(2)) <= opts.radius
        found = found + 1;  correct = correct + 1;
    end
end
m.recall = found / max(withBall, 1);
m.precision = correct / max(said, 1);
m.frames = numel(T);  m.withBall = withBall;
end
