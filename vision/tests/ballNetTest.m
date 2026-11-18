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
