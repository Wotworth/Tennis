function P = ballAt(truth, T)
%BALLAT  Truth ball centre (N-by-3) at truth times T, NaN when out of play.
%   Linear interpolation of the 1 ms truth samples; never across a gap.
T = T(:);
f = (T - truth.T(1)) / (truth.T(2) - truth.T(1)) + 1;
i = floor(f);  a = f - i;
P = nan(numel(T), 3);
ok = i >= 1 & i < numel(truth.T);
if any(ok), P(ok, :) = (1 - a(ok)) .* truth.ballP(i(ok), :) + a(ok) .* truth.ballP(i(ok) + 1, :); end
end
