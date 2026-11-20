% tv.rally.fromPlay (Chris, 20 Nov): with every frame searched, rallies are where the ball was in play,
% joined with the sound's windows; what the sound alone would have skipped is measured.

%% A rally the sound missed is found from the ball; the sound's share is reported
fps = 120;  T = 60;
rec = struct('pts', (0:T * fps - 1)' / fps, 'fps', fps);  rec(2) = rec(1);
sync = struct('startOffset', [0 0]);
d0 = tv.pipeline.defaults();  o = d0.play;
% ball in play 5-12 s (heard) and 30-36 s (not heard); one stray confident spot at 50 s
f1 = [round(5 * fps):round(12 * fps), round(30 * fps):round(36 * fps), round(50 * fps)]';
rows = {[f1, 100 * ones(size(f1)), 100 * ones(size(f1)), 0.9 * ones(size(f1))], zeros(0, 9)};
R0 = struct('windows', [3.5 14]);
R = tv.rally.fromPlay(R0, rows, rec, sync, o);
disp(R.windows)
assert(size(R.windows, 1) == 2)
assert(R.windows(2, 1) <= 30 - 1.4 && R.windows(2, 2) >= 36 + 1.9)     % the unheard rally, with its margins
assert(all(R.windows(:, 2) < 49 | R.windows(:, 1) > 51))                 % one stray spot is not a rally
assert(abs(R.playSeconds - 13.25) < 0.6)
assert(abs(R.soundCoverage - 10.5 / 20) < 0.02)                         % the sound held the first rally only: 10.5 of 20 s
assert(isequal(R.soundWindows, R0.windows))
