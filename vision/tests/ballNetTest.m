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

%% round 4 (no colour, 5 input channels): the probabilities match PyTorch's to 1e-6
net5 = tv.detect.loadBallNet(fullfile(here, 'fixtures', 'ballnet', 'random5_net.json'));
C5 = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'random5_check.json')));
assert(size(net5.conv(1).W, 3) == 5);
p = tv.detect.ballNet(net5, permute(uint8(C5.X), [3 4 5 2 1]), C5.M);
assert(max(abs(p(:) - C5.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - C5.p(:)))));

%% round 4 cuts: tv.detect.ballCrops at the ball's scale gives the Python twin's pixels
K = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'crops_check.json')));
Fr = uint8(K.F);                                            % frame, row, column, channel
fr = @(k) reshape(Fr(k, :, :, :), size(Fr, 2), size(Fr, 3), 3);
X = tv.detect.ballCrops(fr(1), fr(2), fr(3), K.C, 48, K.scale);
want = permute(uint8(K.X), [3 4 5 2 1]);                    % n f h w c -> h w c f n
d = abs(double(X) - double(want));
assert(max(d(:)) <= 1 && mean(d(:) > 0) < 0.01, sprintf('largest difference %d levels, %.2f%% of pixels differ', max(d(:)), 100 * mean(d(:) > 0)));

%% the scale stays within the camera's range
s = tv.detect.ballScale([1; 5; 40], [3 9; 3 9; 3 9]);
assert(isequal(s, [3; 5; 9]), mat2str(s'));

%% round 4's model (vision/models/ballnet_v4.json, no colour) matches PyTorch to 1e-6
net4 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v4.json'));
C4 = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'v4_check.json')));
assert(size(net4.conv(1).W, 3) == 5);
p = tv.detect.ballNet(net4, permute(uint8(C4.X), [3 4 5 2 1]), C4.M);
assert(max(abs(p(:) - C4.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - C4.p(:)))));

%% round 4's model calls a moving ball a ball whatever its colour or the light: yellow, white, dark on a pale court, dim
net4 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v4.json'));
[xx, yy] = meshgrid(0:47, 0:47);
cases = {[225 230 90], [120 115 105], 1; [245 245 240], [70 110 160], 1; [60 55 50], [200 195 185], 1; [225 230 90], [120 115 105], 0.4};
for q = 1:size(cases, 1)
    X = zeros(48, 48, 3, 3, 'uint8');
    for k = 1:3
        img = repmat(reshape(cases{q, 2}, 1, 1, 3), 48, 48);
        on = hypot(xx - (24 + (k - 2) * 9), yy - 24) <= 3;          % 6 px across, as the cuts are scaled
        for c = 1:3, ch = img(:, :, c); ch(on) = cases{q, 1}(c); img(:, :, c) = ch; end
        X(:, :, :, k) = uint8(cases{q, 3} * img);
    end
    p = tv.detect.ballNet(net4, X, [0.8 1.4]);
    assert(p > 0.9, sprintf('case %d: moving ball scored %.2f', q, p));
end

%% round 4's first pass (vision/models/ballnet_v4_pre.json) matches PyTorch to 1e-6 and carries its threshold
pre = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v4_pre.json'));
Cp = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'v4_pre_check.json')));
assert(pre.threshold > 0 && pre.threshold < 0.5);
p = tv.detect.ballNet(pre, permute(uint8(Cp.X), [3 4 5 2 1]), Cp.M);
assert(max(abs(p(:) - Cp.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - Cp.p(:)))));

%% tv.detect.ballScores: what the first pass lets through gets the classifier's score, the rest 0; a moving ball passes
net4 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v4.json'));
pre = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v4_pre.json'));
C4 = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'v4_check.json')));
X = permute(uint8(C4.X), [3 4 5 2 1]);
[xx, yy] = meshgrid(0:47, 0:47);
yellow = [225 230 90];
for k = 1:3                                             % spot 1 becomes a yellow ball crossing a grey court
    img = repmat(reshape([120 115 105], 1, 1, 3), 48, 48);
    on = hypot(xx - (24 + (k - 2) * 9), yy - 24) <= 3;
    for c = 1:3, ch = img(:, :, c); ch(on) = yellow(c); img(:, :, c) = ch; end
    X(:, :, :, k, 1) = uint8(img);
end
M = C4.M;  M(1, :) = [0.8 1.4];
full = tv.detect.ballNet(net4, X, M);
q = tv.detect.ballNet(pre, X(13:36, 13:36, :, :, :), M);
p = tv.detect.ballScores(net4, pre, X, M);
assert(q(1) >= pre.threshold && p(1) > 0.9, sprintf('the ball: first pass %.3f, score %.2f', q(1), p(1)));
assert(all(p(q < pre.threshold) == 0) && max(abs(p(q >= pre.threshold) - full(q >= pre.threshold))) < 1e-12);
assert(isequal(tv.detect.ballScores(net4, [], X, M), full(:)));

%% round 5's model (vision/models/ballnet_v5.json, 7 input channels: round 4's five and two colour-change pictures) matches PyTorch to 1e-6
net5 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v5.json'));
C5 = jsondecode(fileread(fullfile(here, 'fixtures', 'ballnet', 'v5_check.json')));
assert(size(net5.conv(1).W, 3) == 7);
p = tv.detect.ballNet(net5, permute(uint8(C5.X), [3 4 5 2 1]), C5.M);
assert(max(abs(p(:) - C5.p(:))) < 1e-6, sprintf('max difference %.3g', max(abs(p(:) - C5.p(:)))));

%% round 5's model: a moving ball with a colour of its own is a ball; the same patch only darker (a shadow) is not
net5 = tv.detect.loadBallNet(fullfile(fileparts(here), 'models', 'ballnet_v5.json'));
[xx, yy] = meshgrid(0:47, 0:47);
% balls: yellow on grey clay, white on blue, yellow on blue in dim light
balls = {[225 230 90], [120 115 105]; [245 245 240], [70 110 160]; [90 92 36], [28 44 64]};
for q = 1:size(balls, 1)
    X = zeros(48, 48, 3, 3, 'uint8');
    for k = 1:3
        img = repmat(reshape(balls{q, 2}, 1, 1, 3), 48, 48);
        on = hypot(xx - (24 + (k - 2) * 9), yy - 24) <= 3;          % 6 px across, as the cuts are scaled
        for c = 1:3, ch = img(:, :, c); ch(on) = balls{q, 1}(c); img(:, :, c) = ch; end
        X(:, :, :, k) = uint8(img);
    end
    p = tv.detect.ballNet(net5, X, [0.8 1.4]);
    assert(p > 0.9, sprintf('ball %d scored %.2f', q, p));
end
% shadows: the court at 30 to 75% of its brightness, colour unchanged, moving as a ball does. With a
% soft edge and stretched along the ground (as a real shadow is) it is plainly not a ball; even as a
% crisp disc it stays on the "not a ball" side. (Round 4's model, with no colour, scores all of
% these above 0.9: that is the mistake round 5 was trained to stop.)
courts = {[70 110 160], [150 120 100], [120 115 105], [90 140 90]};
for q = 1:numel(courts)
    for f = [0.3 0.45 0.6 0.75]
        for soft = [0 1]
            X = zeros(48, 48, 3, 3, 'uint8');
            for k = 1:3
                d = hypot((xx - (24 + (k - 2) * 9)) / (1 + soft), yy - 24);
                a = double(d <= 3);
                if soft, a = min(max((4 - d) / 2, 0), 1); end
                X(:, :, :, k) = uint8(repmat(reshape(courts{q}, 1, 1, 3), 48, 48) .* (1 - a * (1 - f)));
            end
            p = tv.detect.ballNet(net5, X, [0.8 1.4]);
            if soft, assert(p < 0.1, sprintf('soft shadow on court %d at %.2f scored %.2f', q, f, p));
            else, assert(p < 0.5, sprintf('crisp shadow on court %d at %.2f scored %.2f', q, f, p)); end
        end
    end
end

%% tv.detect.ballModel: round 5 outdoors, round 4 on a court marked indoor or when set by hand; the files exist
m = tv.detect.ballModel();
assert(~isempty(strfind(m.net, 'ballnet_v5.json')) && exist(m.net, 'file') == 2 && exist(m.pre, 'file') == 2);
m = tv.detect.ballModel(true);
assert(~isempty(strfind(m.net, 'ballnet_v4.json')) && exist(m.net, 'file') == 2);
m = tv.detect.ballModel(false, 'somewhere/else.json');
assert(strcmp(m.net, 'somewhere/else.json'));
