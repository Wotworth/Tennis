% full one-camera run + app export for one video; env VID. Picks: check<vid>/picks.m defines
% struct array `picks` (clip, frame, verdict, caption) and struct `check`.
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image; pkg load optim; pkg load statistics
tvcfg;   % sets out (runN, or runNL for the learned detector)
chk = ['/home/user/private-footage/check' vid];  if strncmp(getenv('DET'), 'learned', 7), chk = [chk 'L' getenv('DET')(8:end)]; end
R = tv.pipeline.runSingle(files.(['v' vid]), out, cfg);
if strcmp(getenv('STOP'), 'run'), return; end
printf('%d clips, %d bounces (%d in, %d out)\n', size(R.clips,1), numel(R.bounces), nnz(strcmp({R.bounces.call},'in')), nnz(strcmp({R.bounces.call},'out')));
% Chris's hand-drawn singles court (check only, never input): screenshot -> video px
P = [-11.885 4.115 0; 11.885 4.115 0; 11.885 -4.115 0; -6.4 4.115 0; -6.4 -4.115 0; -6.4 0 0; 6.4 4.115 0; 6.4 -4.115 0];
if strcmp(vid, '1')
  S = [200 860; 915 327; 1370 357; 615 565; 1650 657; 1130 610; 870 368; 1395 395];
  U = [S(:,1)*0.96, (S(:,2)-62)*0.96];
elseif strcmp(vid, '2')
  S = [265 800; 825 232; 1255 232; 580 488; 1610 485; 1100 488; 795 268; 1300 268];
  U = [S(:,1)*0.96, (S(:,2)-62)*0.96];
else
  % clay: the visible drawn points (far baseline corners, near service line and T), on a frame
  % from the first minute, moved onto the stretch's empty court by the camera's drift
  S = [900 280; 1385 293; 530 538; 1790 615; 1130 578];
  U = [S(:,1) * 1920/1999, (S(:,2) - 63) * 1920/1999];
  [~, dsh] = tv.calib.steady(imread('/home/user/private-footage/check3/start_60.png'), R.bg, 120);  U = U - dsh;
  P = P([2 3 4 5 6], :);
end
best = Inf;
for flip = [1 -1]
  Q = P; Q(:,1:2) = flip*Q(:,1:2); [p, ok] = tv.camera.project(R.cam, Q);
  e = sqrt(sum((p-U).^2,2)); e(~ok) = Inf; if median(e) < best, best = median(e); E = e; end
end
printf('scorecard median %.0f px; each %s\n', best, mat2str(round(E')));
run([chk '/picks.m']);
meta = struct('v1', struct('id', 'iphone-2025-04-25', 'title', 'iPhone test 1', 'date', '25 Apr 2025'), ...
              'v2', struct('id', 'iphone-2025-04-16', 'title', 'iPhone test 2', 'date', '16 Apr 2025'), ...
              'v3', struct('id', 'iphone-2025-11-10-clay', 'title', 'Clay, iPhone', 'date', '10 Nov 2025'));
m = meta.(['v' vid]);
src = 'iPhone (SwingVision export)';  if strcmp(vid, '3'), src = 'iPhone (SwingVision, unedited)'; end
opts = struct('id', m.id, 'title', m.title, 'date', m.date, 'source', src, ...
  'pixelate', ~strcmp(vid, '3'), ...   % clay video: Chris has permission to show it unpixelated (18 Nov)
  'frames', picks, 'check', check, 'scorecard', struct('medianPx', round(best), 'perPointPx', round(E')), 'notes', {notes});
T = tv.out.singleTest(R, [out '/export'], opts);
printf('exported to %s/export\n', out);
