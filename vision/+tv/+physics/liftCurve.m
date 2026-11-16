function y = liftCurve(x, mode)
%LIFTCURVE  Truth C_L(S) for synthetic flights: the spec's table line, made to pass through zero.
%   C_L = 0.03 + 0.51 S for S >= 0.14 (TV-SPN-03's initial table, the same
%   one tv.metrics.spin converts with, so AC-11 is "true C_L(S) known"), and
%   a straight line through the origin below (a ball with no spin has no
%   lift). liftCurve(CL, 'inverse') gives S for a lift coefficient.
a = 0.03;  b = 0.51;  s1 = 0.14;  m = (a + b * s1) / s1;
if nargin > 1 && strcmp(mode, 'inverse')
    y = max(x, 0) / m;
    hi = x >= a + b * s1;
    y(hi) = (x(hi) - a) / b;
else
    y = m * max(x, 0);
    hi = x >= s1;
    y(hi) = a + b * x(hi);
end
end
