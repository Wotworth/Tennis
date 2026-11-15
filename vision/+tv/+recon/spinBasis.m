function [e1, e2] = spinBasis(v)
%SPINBASIS  Two spin axes across the flight direction v.
%   e1: horizontal, across the flight; spin about it is topspin (+) or slice
%   (-), whose push is down or up. e2: in the vertical plane of the flight,
%   across it; spin about it is sidespin, whose push is sideways.
u  = v(:)' / max(norm(v), eps);
e1 = cross([0 0 1], u);
if norm(e1) < 1e-6, e1 = [0 1 0]; end
e1 = e1 / norm(e1);
e2 = cross(u, e1);  e2 = e2 / norm(e2);
end
