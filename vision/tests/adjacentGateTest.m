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
% logged once each, from Chris's track or (21 Nov: a track is cut where it switches balls) from the
% piece cut out of it; never from the candidates (0) or the neighbour's own track
r = log([log.cam] == 1 & ismember([log.frame], sw) & ~ismember([log.track], [0, tr{1}(2).id]));
assert(numel(r) == numel(sw) && all(ismember({r.reason}, {'outside court of interest', 'mostly outside'})))

%% A second track wholly inside Chris's track gives up all its points, and the gate finishes
% (16 Nov: an emptied track made the overlap step loop forever)
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine}, fps, 0.3);
dup = tr{1}(1);  sel = 30:60;
dup.frames = dup.frames(sel);  dup.uv = dup.uv(sel, :) + [0 2];  dup.area = dup.area(sel);
tr{1}(2) = dup;
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
assert(numel(kept{1}) == 1 && numel(kept{1}.frames) >= 0.98 * numel(tr{1}(1).frames))
assert(sum(strcmp({log.reason}, 'overlaps a better track')) == numel(sel))

%% A ball rolling across Chris's court is rejected as rolling, not a shot (17 Nov, AC-14)
roller = [5 + 0 * t, -2 - 3 * t, c.ballRadius + 0 * t];
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, roller}, fps, 0.3);
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
for k = 1:2, assert(numel(kept{k}) == 1, 'camera %d kept %d tracks', k, numel(kept{k})), end
assert(any(strcmp({log.reason}, 'rolling on the ground')))

%% Two balls in the air over Chris's court at once both keep their tracks (17 Nov, AC-15)
% the overlap step must not treat two different balls as two tracks of one
other = [5 + 0 * t, -2 - 3 * t, 1.5 + 2 * t - 2.5 * t.^2];
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, other}, fps, 0.3);
[kept, log, partners] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
for k = 1:2
    assert(numel(kept{k}) == 2, 'camera %d kept %d tracks', k, numel(kept{k}))
end
assert(~any(strcmp({log.reason}, 'overlaps a better track')))
% and they are fitted apart: two groups, each seen by both cameras
G = tv.recon.ballGroups(kept, partners);
assert(numel(G) == 2)
assert(all(cellfun(@(g) numel(g{1}) == 1 && numel(g{2}) == 1, G)))

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

%% A point paired with another ball's track off its own path is dropped (21 Nov, Chris: why does pairing
% ever take the other ball?). A stray rolls across Chris's court; camera 2 loses it for 15 frames.
% Meanwhile camera 2 sees a ball lying exactly on camera 1's sight line through the stray (a ball
% in the air that camera 1 sees behind the stray), so the stray's camera-1 points pair with it
% perfectly and land 1 to 1.5 m up. Before: kept (the 90% rolling test then had to hide them).
stray = [-6 + 3 * t, -2 + 0 * t, c.ballRadius + 0 * t];
dirs = stray - cams(1).pos;
up = 1.0 + 0.5 * t;                                       % the other ball's height along that sight line
s = (up - cams(1).pos(3)) ./ dirs(:, 3);
phantom = cams(1).pos + s .* dirs;
gap = 50:64;
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {stray, phantom}, fps, 0.3);
% camera 1 can't see the phantom apart from the stray (it lies behind it): only camera 2's track stays
tr{1} = tr{1}(1);  cand{1} = cand{1}(ismember(cand{1}(:, 1:3), [double(tr{1}.frames), tr{1}.uv], 'rows'), :);
keep = ~ismember(tr{2}(1).frames, gap);                  % camera 2 loses the stray for 15 frames
tr{2}(1).frames = tr{2}(1).frames(keep);  tr{2}(1).uv = tr{2}(1).uv(keep, :);  tr{2}(1).area = tr{2}(1).area(keep);
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct('rollShare', 1));
r = log([log.cam] == 1 & ismember([log.frame], gap));
fprintf('camera 1 stray points in the gap: %d logged, reasons %s\n', numel(r), strjoin(unique({r.reason}), ', '));
% judged on every point (rollShare 1, the rule before 20 Nov), the stray is recognised as rolling and
% rejected whole: its points paired with the other ball no longer count as its own
assert(isempty(kept{1}) && all(strcmp({r.reason}, 'rolling on the ground')))

%% A track that runs on from the neighbours' ball onto Chris's is cut, and his part kept (21 Nov,
% Chris: CI run 56 lost his serve in camera 2 inside a track that was mostly the neighbours' ball)
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, theirs}, fps, 0.3);
a = tr{2}(1);  b = tr{2}(2);                              % camera 2: 1 = mine, 2 = theirs
A = b.frames < 80;  B = a.frames >= 80;                 % theirs until frame 79, then mine
mixed = struct('frames', [b.frames(A); a.frames(B)], 'uv', [b.uv(A, :); a.uv(B, :)], 'area', [b.area(A); a.area(B)], 'id', 1);
tr{2} = mixed;
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
km = [];  for q = 1:numel(kept{2}), km = [km; kept{2}(q).frames(:)]; end %#ok<AGROW>
fprintf('camera 2 keeps %d of Chris''s %d points after the switch\n', nnz(ismember(a.frames(B), km)), nnz(B));
assert(nnz(ismember(a.frames(B), km)) >= 0.9 * nnz(B))
assert(~any(ismember(b.frames(A), km)))                  % and none of the neighbours'

%% A track that alternates between the neighbours' ball and Chris's, frame by frame, is split by ball
% (21 Nov: CI run 58 showed a camera-2 track with 153 of his points and 463 of the neighbours',
% dropped whole as "mostly outside")
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, theirs}, fps, 0.3);
a = tr{2}(1);  b = tr{2}(2);
fa = a.frames(mod(a.frames, 3) == 0 & a.frames >= 20);   % his ball every third frame from 20 on
fb = setdiff(b.frames, fa);                              % the neighbours' the rest
[~, ia] = ismember(fa, a.frames);  [~, ib] = ismember(fb, b.frames);
alt = struct('frames', [fa; fb], 'uv', [a.uv(ia, :); b.uv(ib, :)], 'area', [a.area(ia); b.area(ib)], 'id', 1);
[~, o] = sort(alt.frames);  alt.frames = alt.frames(o);  alt.uv = alt.uv(o, :);  alt.area = alt.area(o);
tr{2} = alt;
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
km = [];  for q = 1:numel(kept{2}), km = [km; kept{2}(q).frames(:)]; end %#ok<AGROW>
fprintf('alternating: camera 2 keeps %d of Chris''s %d points, %d of the neighbours'' %d\n', nnz(ismember(fa, km)), numel(fa), nnz(ismember(fb, km)), numel(fb));
assert(nnz(ismember(fa, km)) >= 0.9 * numel(fa) && ~any(ismember(fb, km)))

%% Two camera-2 tracks that swap the two balls in blocks: camera 1's clean tracks stay whole, and
% Chris's points come back from both (21 Nov: CI run 59, a first split-by-ball cut camera 1's clean
% track of his ball and lost 40% of it)
[tr, cand, rec, sync] = tv.testing.ballTracks(cams, {mine, theirs}, fps, 0.3);
a = tr{2}(1);  b = tr{2}(2);  f = (0:N - 1)';
blk = mod(floor(f / 20), 2) == 0;                        % blocks of 20 frames
mk2 = @(useA) struct('frames', f, 'uv', [a.uv .* useA + b.uv .* ~useA], 'area', 20 * ones(N, 1), 'id', 0);
assert(isequal(a.frames, f) && isequal(b.frames, f))
t1 = mk2(blk);  t1.id = 1;  t2 = mk2(~blk);  t2.id = 2;
tr{2} = [t1, t2];
[kept, log] = tv.recon.gateTracks(tr, cand, cams, rec, sync, box, struct());
km = [];  for q = 1:numel(kept{2}), km = [km; kept{2}(q).frames(:), kept{2}(q).uv]; end %#ok<AGROW>
mineKept = ismember(round([f, a.uv]), round(km), 'rows');
fprintf('blocks: camera 1 keeps %d tracks (%d points); camera 2 keeps %d of Chris''s %d points\n', numel(kept{1}), sum(arrayfun(@(x) numel(x.frames), kept{1})), nnz(mineKept), N);
assert(numel(kept{1}) == 1 && numel(kept{1}.frames) >= 0.95 * N)
assert(nnz(mineKept) >= 0.9 * N)
