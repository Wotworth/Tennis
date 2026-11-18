import sys, itertools, valscore as V
tag = sys.argv[1]
reach = {}
for i, v, fr in V.F:
    n = sum(1 for x, y, d in V.LAB.get(i, []) if d == 'ball')
    g = 'clay' if v == 4 else 'v%d' % v; reach[g] = reach.get(g, 0) + (1 if n else 0)
print('frames with a ball (the most one-ball-in-play can find):', reach, sum(reach.values()), flush=True)
res = []
for cut, mv, tc, gc in itertools.product((0.05, 0.3), (4.0, 6.0, 10.0), (0.1, 0.15, 0.25), (0.4,)):
    o = V.score(tag, cut=cut, MIN_VALUE=mv, TURN_COST=tc, GAP_COST=gc)
    res.append((o['all'][1], -o['all'][2], cut, mv, tc, gc, o))
    V.show(o, '%s cut %.2f minv %.0f turn %.2f gap %.1f' % (tag, cut, mv, tc, gc))
