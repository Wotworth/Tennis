addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
for v = 1:3
  K = load(sprintf('/home/user/private-footage/run%d/stages/calib.mat', v)).out;
  imwrite(uint8(K.bg), sprintf('/home/user/private-footage/ml/bg_v%d.png', v));
  C = load(sprintf('/home/user/private-footage/run%d/stages/clips.mat', v)).out.clips;
  dlmwrite(sprintf('/home/user/private-footage/ml/clips_v%d.csv', v), C);
end
