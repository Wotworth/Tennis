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

%% With both cameras, a neighbour's ball, a walking player and a rolling ball do not join Chris's rallies into one
% (adjacentTest, CI run 55: counted from either camera alone, the neighbours' play made the whole
% clip one rally and his shots were lost in it)
fps = 60;  T = 40;
rec = struct('pts', (0:T * fps - 1)' / fps, 'fps', fps);  rec(2) = rec(1);
sync = struct('startOffset', [0 0]);
cams = tv.synth.cameras(tv.synth.defaultScenario());
c = tv.court.constants();
fr = (0:T * fps - 1)';  t = fr / fps;
% Chris's ball over his court 5-10 s and 25-30 s; the neighbour's ball over theirs all the time
mine = (t >= 5 & t <= 10) | (t >= 25 & t <= 30);
Pm = [10 * (4 * abs(mod(t / 2, 1) - 0.5) - 1), 2 * cos(t / 3), 1 + 0.5 * sin(5 * t)];   % end to end at 20 m/s
Pn = [6 * sin(t / 2), c.halfDoubles + 3.66 + 5.5 + 2 * cos(t), 1 + 0.8 * abs(sin(3 * t))];
% between his rallies: a player walking past the net post with a confident false spot on him in
% one frame in four (pipelineTest, run 55), and a ball rolling across the court
walk = t > 12 & t < 23 & mod(fr, 4) == 0;
Pw = [0.3 * sin(t), -6.5 + 1.4 * (t - 12) / 11 * 9, 1.7 + 0 * t];
roll = t > 13 & t < 22;
Pr = [-8 + 1.8 * (t - 13), 3 + 0 * t, 0.033 + 0 * t];
rows = cell(1, 2);
for k = 1:2
    [pm, okm] = tv.camera.project(cams(k), Pm);  [pn, okn] = tv.camera.project(cams(k), Pn);
    [pw, okw] = tv.camera.project(cams(k), Pw);  [pr, okr] = tv.camera.project(cams(k), Pr);
    a = mine & okm;  b = okn;  w = walk & okw;  q = roll & okr;
    rows{k} = [fr(a), pm(a, :), 0.9 * ones(nnz(a), 1); fr(b), pn(b, :), 0.9 * ones(nnz(b), 1); ...
        fr(w), pw(w, :), 0.9 * ones(nnz(w), 1); fr(q), pr(q, :), 0.9 * ones(nnz(q), 1)];
end
[~, ok1] = tv.camera.project(cams(1), Pn);  [~, ok2] = tv.camera.project(cams(2), Pn);
assert(nnz(ok1 & ok2) > 0.5 * numel(t))                                     % the neighbour's ball is in view of both
d0 = tv.pipeline.defaults();  o = d0.play;
Rone = tv.rally.fromPlay(struct('windows', zeros(0, 2)), rows, rec, sync, o);
Rtwo = tv.rally.fromPlay(struct('windows', zeros(0, 2)), rows, rec, sync, o, cams, tv.court.interest());
fprintf('either camera alone: %s\nboth cameras paired: %s\n', mat2str(Rone.windows, 3), mat2str(Rtwo.windows, 3));
assert(size(Rone.windows, 1) == 1)                                          % what went wrong in run 55
assert(size(Rtwo.windows, 1) == 2)
assert(Rtwo.windows(1, 1) <= 5 - 1.4 && Rtwo.windows(1, 2) >= 10 + 1.9 && Rtwo.windows(1, 2) <= 10 + 2.6)
assert(Rtwo.windows(2, 1) >= 25 - 1.6 && Rtwo.windows(2, 1) <= 25 - 1.4 && Rtwo.windows(2, 2) >= 30 + 1.9)
