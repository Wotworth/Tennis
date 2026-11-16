% Only Chris's court (TV-ADJ-01 to 05): the court of interest, the stereo gate,
% the track filter and the player filter, on balls with known positions.
% (The whole pipeline with neighbouring courts on footage: adjacentTest.m.)
tv.util.seed(3);
sc = tv.synth.defaultScenario();  sc.frameSize = [3840 2160];  sc.aimErrorDeg = 0 * sc.aimErrorDeg;
cams = tv.synth.cameras(sc);
fps = 120;  N = 120;  t = (0:N - 1)' / fps;
c = tv.court.constants();
box = tv.court.interest(struct('behindBaseline', 5, 'beyondSideline', 2, 'maxHeight', 12));
nb = c.halfDoubles + 3.66 + c.halfDoubles;                % the next court's centre line, y
% Chris's ball: across his court
mine = [-10 + 18 * t, 1 + 0.5 * t, 1 + 4 * t - 4.9 * t.^2];
% the far neighbour's ball: across their court, in view of both cameras
theirs = [8 - 16 * t, nb + 0.3 * t, 1.2 + 3.5 * t - 4.9 * t.^2];
% a stray ball rolling from the neighbour's court onto Chris's: mostly outside
roll = [4 + 0 * t, nb - 2 - 6 * t, c.ballRadius + 0 * t];
% people: Chris and his opponent, a neighbour by the shared sideline, one on the next court
T = (0:0.1:20)';
mk = @(xy) struct('t', T, 'xy', xy, 'cap', zeros(size(T)), 'shirt', zeros(numel(T), 3), 'height', 1.8 * ones(size(T)), ...
    'v', [0 0], 'lastT', T(end), 'ambiguous', false(size(T)));
pl = [mk([-12 + 0 * T, 2 * sin(T)]), mk([12 + 0 * T, -1 + 2 * cos(T)]), ...
      mk([0 * T + 3, c.halfDoubles + 3.0 + 0.3 * sin(T)]), mk([0 * T - 5, nb + 0 * T])];
info = struct('chris', 2, 'confidence', [1 0.95 1 1]);

%% The court of interest: 5 m behind the baselines, 2 m beyond the doubles sidelines, 12 m high
assert(abs(box.x(2) - (c.halfLength + 5)) < 1e-9 && abs(box.y(2) - (c.halfDoubles + 2)) < 1e-9 && box.z(2) == 12)
assert(tv.court.inInterest([0 0 1], box) && ~tv.court.inInterest([0 nb 1], box) && ~tv.court.inInterest([0 0 13], box))
% the neighbour's doubles sideline (3.66 m away) is outside
assert(~tv.court.inInterest([0 c.halfDoubles + 3.66 0.1], box))

%% Chris's ball is kept whole; the neighbour's ball and the rolling stray are rejected
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, theirs, roll}, fps, 0.3);
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
for k = 1:2
    assert(numel(kept{k}) == 1, 'camera %d kept %d tracks', k, numel(kept{k}))
    assert(numel(kept{k}.frames) >= 0.98 * numel(tr{k}(1).frames), 'Chris''s ball lost points')
end
reasons = unique({log.reason});
assert(any(strcmp(reasons, 'mostly outside')), strjoin(reasons, ', '))
assert(~any(strcmp(reasons, 'implausible jump')))

%% A neighbour's ball crossing in front of Chris's ball in one camera does not join it
% camera 1's track swaps onto the neighbour's ball for 10 frames (what a 2D tracker can do)
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, theirs}, fps, 0.3);
sw = 40:49;
[p, ok] = tv.camera.project(cams(1), theirs(sw + 1, :));
assert(all(ok))
i = ismember(tr{1}(1).frames, sw);
tr{1}(1).uv(i, :) = p(ismember(sw, tr{1}(1).frames), :);
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
k1 = kept{1}(1);
assert(~any(ismember(k1.frames, sw)), 'the swapped frames stayed in Chris''s track')
r = log([log.cam] == 1 & ismember([log.frame], sw) & [log.track] == 1);
assert(numel(r) == numel(sw) && all(strcmp({r.reason}, 'outside court of interest')))

%% A second track wholly inside Chris's track gives up all its points, and the gate finishes
% (16 Nov: an emptied track made the overlap step loop forever)
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine}, fps, 0.3);
dup = tr{1}(1);  sel = 30:60;
dup.frames = dup.frames(sel);  dup.uv = dup.uv(sel, :) + [0 2];  dup.area = dup.area(sel);
tr{1}(2) = dup;
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
assert(numel(kept{1}) == 1 && numel(kept{1}.frames) >= 0.98 * numel(tr{1}(1).frames))
assert(sum(strcmp({log.reason}, 'overlaps a better track')) == numel(sel))

%% Every rejected detection is logged with a reason, and isolated candidates too
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine}, fps, 0.3);
cand{1}(end+1, :) = [10 100 100 20 1 1];                   % a lone blob in no track
[~, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
assert(any(strcmp({log.reason}, 'isolated') & [log.frame] == 10))
assert(all(~cellfun(@isempty, {log.reason})))

%% Only the two players on Chris's court are kept; a neighbour by the shared sideline is not
[k2, info2, plog] = tv.players.keepCourt(pl, info, box, struct('playerInsideFrac', 0.6));
assert(numel(k2) == 2 && info2.chris == 2 && isequal(info2.confidence, [1 0.95]))
assert(numel(plog) == 2 && all(strcmp({plog.reason}, 'person off court')))

%% Never more than two people on court at once
pl(3) = mk([0 * T + 6, 0 * T + 1]);                        % a third person walks on court
[k3, ~, plog] = tv.players.keepCourt(pl, info, box, struct('playerInsideFrac', 0.6));
assert(numel(k3) == 2 && any(strcmp({plog.reason}, 'third person on court')))
