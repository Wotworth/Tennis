function lg = netLayers(inputSize, width)
%NETLAYERS  A small TrackNet-style ball detector (TV-DET-04): three frames in, a heat map out.
%   inputSize [H W] of the (downscaled) frames; the input stacks three
%   consecutive RGB frames (9 channels). An encoder-decoder of plain
%   convolutions predicts, per pixel, how likely the ball is there (a
%   Gaussian blob on the training labels). width sets the channel count
%   (16 for tests, 32-64 on the PC).
%   RETUNE(real footage): input size, width and depth, chosen on the PC's GPU.
if nargin < 2, width = 32; end
w = width;
lg = [
    imageInputLayer([inputSize 9], 'Normalization', 'none', 'Name', 'in')
    convolution2dLayer(3, w, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    convolution2dLayer(3, w, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer('Name', 'skip1')
    maxPooling2dLayer(2, 'Stride', 2)
    convolution2dLayer(3, 2 * w, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    convolution2dLayer(3, 2 * w, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    transposedConv2dLayer(2, w, 'Stride', 2)
    reluLayer
    convolution2dLayer(3, w, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    convolution2dLayer(1, 1)
    sigmoidLayer('Name', 'heat')];
end
