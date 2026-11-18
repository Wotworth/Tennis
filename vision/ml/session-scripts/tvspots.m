% learned clay run: every tracked point (clip, frame, court-px u v) and the points found, for the
% spot check and the sample frames (Python cuts the crops)
addpath('/tmp/claude-0/scratchpad/vsnap');
addpath('/tmp/claude-0/scratchpad/vsnap');
suf = getenv('SUF');  R = load(['/home/user/private-footage/run3L' suf '/single.mat']);
fid = fopen(['/home/user/private-footage/check3L' suf '/tracked.csv'], 'w');
for r = 1:numel(R.tracks)
  for t = R.tracks{r}(:)'
    for j = 1:numel(t.frames), fprintf(fid, '%d,%d,%.2f,%.2f,%d\n', r, t.frames(j), t.uv(j, 1), t.uv(j, 2), t.id); end
  end
end
fclose(fid);
dlmwrite(['/home/user/private-footage/check3L' suf '/points.csv'], R.points);
dlmwrite(['/home/user/private-footage/check3L' suf '/clips.csv'], R.clips);
b = R.bounces; fid = fopen(['/home/user/private-footage/check3L' suf '/bounces.csv'], 'w');
for i = 1:numel(b), fprintf(fid, '%d,%d,%.2f,%.2f,%.2f,%.2f,%s\n', b(i).clip, b(i).frame, b(i).u, b(i).v, b(i).x, b(i).y, b(i).call); end
fclose(fid);
printf('%d tracks, %d points, %d bounces\n', sum(cellfun(@numel, R.tracks)), size(R.points, 1), numel(b));
