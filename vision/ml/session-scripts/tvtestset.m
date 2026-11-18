% dump 16 random frames per video for the hand-labelled test set, with each frame's shift against
% the empty court (labels are in raw frame pixels; tracks are in the empty court's pixels)
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
rand('seed', 1811);
for v = 1:3
  run = sprintf('/home/user/private-footage/run%d', v); out = sprintf('/home/user/private-footage/testset/v%d', v);
  if ~exist(out, 'dir'), mkdir(out); end
  rec = load([run '/stages/probe.mat']).out; K = load([run '/stages/calib.mat']).out; C = load([run '/stages/clips.mat']).out.clips;
  if v == 3, C = C(1:12, :); end
  fr = [];  for r = 1:size(C,1), fr = [fr, C(r,1):C(r,2)]; end %#ok<AGROW>
  pick = sort(fr(randperm(numel(fr), 16)));
  boxes = [1630 10 1915 470; 1430 925 1915 1070]; if v == 3, boxes = zeros(0,4); end
  fid = fopen([out '/frames.csv'], 'w');
  for i = 1:numel(pick)
    img = tv.media.readFrames(rec, pick(i), 1);
    G = img; for b = 1:size(boxes,1), G(boxes(b,2):boxes(b,4), boxes(b,1):boxes(b,3), :) = 128; end
    [~, d] = tv.calib.steady(G, K.bg, 40);
    imwrite(img, sprintf('%s/f%02d.png', out, i));
    fprintf(fid, '%d,%d,%d,%d\n', i, pick(i), d(1), d(2));
  end
  fclose(fid);
end
