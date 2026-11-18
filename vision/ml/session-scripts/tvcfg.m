% shared settings for tvrun.m and tvexport.m (env VID)
vid = getenv('VID');
files = struct('v1', '/home/user/private-footage/video.bin', 'v2', '/home/user/private-footage/video2.bin', 'v3', '/home/user/private-footage/v3/video3_mid.mp4');
file = files.(['v' vid]);
out = ['/home/user/private-footage/run' vid];
cfg = tv.pipeline.defaults();
cfg.chunk = 30;
cfg.notify = @(a, b) printf('[alert] %s: %s\n', a, b);
cfg.single = struct('overlayBoxes', [1630 10 1915 470; 1430 925 1915 1070], ...
  'detectOpts', struct('hue', [55 140], 'minSat', 0.12, 'minVal', 0.75, 'bigPatchArea', 400));
if strcmp(vid, '3')   % raw iPhone footage, no SwingVision overlays (17 Nov)
  cfg.single.overlayBoxes = zeros(0, 4);  cfg.single.wholeFile = true;  cfg.single.maxWindows = 12;   % 6 min (Chris: within the hour)
  % indoor warm light: the ball is nearly white with an orange cast, the clay orange and darker
  cfg.single.detectOpts = struct('hue', [20 90], 'minSat', 0.08, 'minVal', 0.80, 'bigPatchArea', 400, ...
    'skipLinesPx', 3, 'diffThr', 90, 'motionThr', 60);
end
% the learned detector (TV-DET-04, 18 Nov): env DET=learned; results in runNL, the Python twin's
% per-clip detections read from runNL/pre (same model as tv.detect.ballNet)
if strncmp(getenv('DET'), 'learned', 7)
  out = [out 'L' getenv('DET')(8:end)];   % learned -> runNL, learned2 -> runNL2 (round-2 model)
  cfg.single.detector = 'learned';  cfg.single.precomputed = [out '/pre'];
  cfg.single.detectOpts = struct();
end
