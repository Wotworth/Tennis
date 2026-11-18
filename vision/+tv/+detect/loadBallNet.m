function net = loadBallNet(file)
%LOADBALLNET  The ball classifier's weights (tv.detect.ballNet) from its JSON file.
J = jsondecode(fileread(file));
for k = 1:numel(J.conv)
    c = J.conv(k);  if iscell(J.conv), c = J.conv{k}; end
    W = c.W;  if iscell(W), W = cell2mat(W); end
    net.conv(k).W = reshape(double(W), size(c.W));          %#ok<AGROW> 3 x 3 x cin x cout
    net.conv(k).b = double(c.b(:));                           %#ok<AGROW>
    net.conv(k).pool = logical(c.pool);                       %#ok<AGROW>
end
net.fc1.W = double(J.fc1.W);  net.fc1.b = double(J.fc1.b(:));
net.fc2.W = double(J.fc2.W(:)');  net.fc2.b = double(J.fc2.b);
end
