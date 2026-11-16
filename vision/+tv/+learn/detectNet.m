function C = detectNet(model, X, opts)
%DETECTNET  The learned detector on one input (three frames): candidates [u v score].
%   The heat map's strongest peak above opts.minScore, refined to sub-pixel
%   by the weighted centre of its neighbourhood. GPU when there is one.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'minScore'), opts.minScore = 0.3; end
env = 'cpu';  if tv.util.useGpu(), env = 'gpu'; end
H = double(gather(minibatchpredict(model.net, single(X), 'ExecutionEnvironment', env)));
[s, i] = max(H(:));
C = zeros(0, 3);
if s < opts.minScore, return; end
[r, q] = ind2sub(size(H), i);
r0 = max(1, r - 2):min(size(H, 1), r + 2);  q0 = max(1, q - 2):min(size(H, 2), q + 2);
w = H(r0, q0);  [Q, R] = meshgrid(q0, r0);
C = [sum(Q(:) .* w(:)) / sum(w(:)), sum(R(:) .* w(:)) / sum(w(:)), s];
end
