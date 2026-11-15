function cuts = splitEvents(trk, opts)
%SPLITEVENTS  Frames where a 2D track changes course abruptly: hits and bounces (TV-TRK-02).
%   At each point, fits a parabola (in time) to the points just before and
%   just after it, and compares the two velocities there. A jump well above
%   what noise and drag explain marks an event. Returns frame numbers.
%   RETUNE(real footage): window length and thresholds.
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'window'), opts.window = 7; end
if ~isfield(opts, 'minJump'), opts.minJump = 1.2; end      % px per frame
if ~isfield(opts, 'relJump'), opts.relJump = 0.25; end     % fraction of speed
f = double(trk.frames(:));  uv = trk.uv;  n = numel(f);  w = opts.window;
jump = zeros(n, 1);
for i = 1:n
    L = find(f <= f(i) & f >= f(i) - 2*w);  R = find(f >= f(i) & f <= f(i) + 2*w);
    if numel(L) < 5 || numel(R) < 5, continue; end
    L = L(max(1, end - w + 1):end);  R = R(1:min(w, end));
    vL = slopeAt(f(L), uv(L, :), f(i));  vR = slopeAt(f(R), uv(R, :), f(i));
    jump(i) = norm(vL - vR) / max(opts.minJump + opts.relJump * norm(vL + vR) / 2, eps);
end
cuts = [];
for i = 2:n - 1
    if jump(i) > 1 && jump(i) >= jump(i - 1) && jump(i) >= jump(i + 1)
        if isempty(cuts) || f(i) - cuts(end) > 4, cuts(end+1) = f(i); end %#ok<AGROW>
    end
end
end

function v = slopeAt(t, P, t0)
% velocity at t0 of a parabola fitted to points P(t)
X = [ones(size(t)), t - t0, (t - t0).^2];
c = X \ P;
v = c(2, :);
end
