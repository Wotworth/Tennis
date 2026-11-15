function [x0, ok] = initSegment(obs, t, cams, CD)
%INITSEGMENT  Starting values for a segment fit: triangulate, then fit a parabola (TV-REC-01).
%   obs rows: [cam frame u v]; t: their session times. For every camera-2
%   detection, camera 1's track is interpolated to the same instant (the
%   cameras are not genlocked) and the two sight lines are triangulated.
%   A parabola through those 3D points gives the start position and velocity.
%   x0 = [p0 v0 0 0 CD] at time min(t) - 1 ms.
x0 = [];  ok = false;
t0 = min(t) - 0.001;
i1 = obs(:, 1) == 1;  i2 = obs(:, 1) == 2;
if nnz(i1) < 3 || nnz(i2) < 3, return; end
[t1, o] = sort(t(i1));  uv1 = obs(i1, 3:4);  uv1 = uv1(o, :);
t2 = t(i2);  uv2 = obs(i2, 3:4);
inside = t2 > t1(1) & t2 < t1(end);
if nnz(inside) < 3, return; end
q1 = [interp1(t1, uv1(:,1), t2(inside)), interp1(t1, uv1(:,2), t2(inside))];
[P, gap] = tv.recon.triangulate(cams(1), q1, cams(2), uv2(inside, :));
good = gap < 0.5;
if nnz(good) < 3, return; end
tt = t2(inside) - t0;  tt = tt(good);  P = P(good, :);
X = [ones(size(tt)), tt, tt.^2 / 2];
c = X \ P;
x0 = [c(1, :), c(2, :), 0, 0, CD];
ok = all(isfinite(x0));
end
