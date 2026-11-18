% tv.detect.ballNet gives the PyTorch model's numbers (a saved case with known weights)
here = fileparts(mfilename('fullpath'));
net = tv.detect.loadBallNet(fullfile(here, 'fixtures', 'ballnet', 'random_net.json'));
C = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'random_check.json')));

%% the weights load with the shapes of the model
assert(isequal(size(net.conv(1).W), [3 3 15 24]), mat2str(size(net.conv(1).W)));
assert(numel(net.conv) == 6 && isequal(size(net.fc1.W), [32 98]));

%% the probabilities match PyTorch's to 1e-6
X = uint8(C.X);                                   % n f h w c (as saved from Python)
X = permute(X, [3 4 5 2 1]);                      % h w c f n
p = tv.detect.ballNet(net, X, C.M);
assert(max(abs(p(:) - C.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - C.p(:)))));

%% the shipped model (vision/models/ballnet_v2.json, round 2) matches PyTorch to 1e-6
net1 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v2.json'));
C1 = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'v2_check.json')));
p = tv.detect.ballNet(net1, permute(uint8(C1.X), [3 4 5 2 1]), C1.M);
assert(max(abs(p(:) - C1.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - C1.p(:)))));

%% the shipped model calls a small ball moving across three frames a ball
net1 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v2.json'));
[xx, yy] = meshgrid(0:47, 0:47);
X = zeros(48, 48, 3, 3, 'uint8');  ballColour = [225 230 90];
for k = 1:3
    img = repmat(reshape([120 115 105], 1, 1, 3), 48, 48);
    on = hypot(xx - (24 + (k - 2) * 6), yy - 24) <= 2.5;
    for c = 1:3, ch = img(:, :, c); ch(on) = ballColour(c); img(:, :, c) = ch; end
    X(:, :, :, k) = uint8(img);
end
p = tv.detect.ballNet(net1, X, [4 9]);
assert(p > 0.9, sprintf('moving ball scored %.2f', p));
