function C = gated(fn, F)
%GATED  Call a fake detector, returning no candidate for a frame with no ball (tests).
if any(isnan(F)), C = zeros(0, 3); else, C = fn(F); end
end
