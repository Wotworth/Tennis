function model = train(samples, opts)
%TRAIN  Train the learned ball detector on auto-labelled frames (TV-DET-04, Chris 15 Nov).
%   samples: struct array with X (H x W x 9 single: three consecutive
%   frames, scaled 0-1) and xy (the ball in X's pixels, NaN when there is
%   none). Targets are Gaussian blobs (opts.sigma px). Uses the GPU when
%   there is one, else the CPU (same result, slower). Hand-labelled test
%   frames must never be passed here (tv.learn.saveAutolabels refuses them).
%   Returns model: net, inputSize, name, trainedUtc, samples.
if nargin < 2, opts = struct(); end
d = struct('width', 32, 'epochs', 8, 'batch', 16, 'sigma', 2.5, 'learnRate', 1e-3, 'name', '');
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
sz = size(samples(1).X);  sz = sz(1:2);
X = cat(4, samples.X);
Y = zeros([sz 1 numel(samples)], 'single');
[gx, gy] = meshgrid(1:sz(2), 1:sz(1));
for k = 1:numel(samples)
    p = samples(k).xy;
    if all(isfinite(p)), Y(:, :, 1, k) = exp(-((gx - p(1)).^2 + (gy - p(2)).^2) / (2 * opts.sigma^2)); end
end
env = 'cpu';  if tv.util.useGpu(), env = 'gpu'; end
o = trainingOptions('adam', 'MaxEpochs', opts.epochs, 'MiniBatchSize', opts.batch, ...
    'InitialLearnRate', opts.learnRate, 'Shuffle', 'every-epoch', 'Verbose', false, ...
    'ExecutionEnvironment', env);
net = trainnet(X, Y, dlnetwork(tv.learn.netLayers(sz, opts.width)), 'mse', o);
model = struct('net', net, 'inputSize', sz, 'name', opts.name, 'trainedUtc', tv.util.nowUtc(), 'samples', numel(samples));
if isempty(model.name), model.name = ['net-' model.trainedUtc]; end
end
