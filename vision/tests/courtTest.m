% Court model (TV-ARCH-10; TV-TST-02).
c = tv.court.constants();

%% Baselines and sidelines
assert(abs(c.halfLength - 11.885) < 1e-9)
assert(abs(c.halfDoubles - 5.485) < 1e-9)

%% The net is 0.914 m at the centre and 1.07 m at the posts
assert(abs(tv.court.netHeight(0) - 0.914) < 1e-9)
assert(abs(tv.court.netHeight(c.postY) - 1.07) < 1e-9)
assert(abs(tv.court.netHeight(-c.postY) - 1.07) < 1e-9)

%% The net sags in a straight line between them
mid = tv.court.netHeight(c.postY / 2);
assert(abs(mid - (0.914 + 1.07) / 2) < 1e-9)

%% No net beyond the posts
assert(isnan(tv.court.netHeight(c.postY + 0.1)))

%% The play volume runs 3 m behind each baseline and up to 4 m
P = tv.court.playVolume(3, 4, 2);
assert(abs(max(P(:,1)) - 14.885) < 1e-9 && abs(min(P(:,1)) + 14.885) < 1e-9)
assert(abs(max(abs(P(:,2))) - 5.485) < 1e-9)
assert(abs(min(P(:,3)) - c.ballRadius) < 1e-9 && abs(max(P(:,3)) - 4) < 1e-9)
