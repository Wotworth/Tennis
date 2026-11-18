% one-camera run for the iPhone test videos; env: VID (1|2), CLIPS (e.g. "1:10" or "all" or "prep")
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image; pkg load optim; pkg load statistics
tvcfg;
c = getenv('CLIPS');
if strcmp(c, 'all')
  R = tv.pipeline.runSingle(file, out, cfg);
  printf('done: %d clips, %d bounces\n', size(R.clips, 1), numel(R.bounces));
else
  cfg.single.detectOnly = true;
  if strcmp(c, 'prep'), cfg.single.clipList = 1; else, cfg.single.clipList = eval(c); end
  tv.pipeline.runSingle(file, out, cfg);
  printf('worker %s done\n', c);
end
