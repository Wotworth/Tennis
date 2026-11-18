addpath('/tmp/claude-0/scratchpad/vsnap');
for v = 1:3
  rec = load(sprintf('/home/user/private-footage/run%d/stages/probe.mat', v)).out;
  fid = fopen(sprintf('/home/user/private-footage/ml/pts_v%d.f64', v), 'w'); fwrite(fid, rec.pts, 'float64'); fclose(fid);
  printf('v%d %s %.3f %d\n', v, rec.file, rec.fps, rec.nFrames);
end
