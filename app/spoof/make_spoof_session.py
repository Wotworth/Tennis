#!/usr/bin/env python3
"""The app's bundled SPOOF vision session (Chris, 16 Nov): made-up results with no even number
anywhere they show, so an even number on a vision screen did not come from the session.

Writes app/src/main/assets/vision/sample/{session,shots,rallies,trajectories,hr,trends,checks}.json.
Every value is chosen in the units the app shows (mph, ft, in, %, deg, bpm) and converted back to
the files' SI units, so the app's rounding gives the chosen number back. Values of one measure are
all 1 more than a multiple of 4 (in the shown unit, or in tenths when shown with one decimal):
then the average of any two of them, which is what a median of an even count shows, is odd too.
Counts that the app adds up (shots per player, per type, per spin kind; bounces per filter) are
made odd by construction and checked at the end, with the app's own sums mirrored here.
The final check is the app's test SpoofOddNumbersTest, which reads every vision screen.

Run: python3 app/spoof/make_spoof_session.py   (no arguments; fixed seed)
"""
import json, math, os, random, statistics

OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'assets', 'vision', 'sample')
MPH = 2.236936
FT = 3.280840
IN = FT * 12
G = 9.81
R_BALL = 0.0335
HALF_L, HALF_S, SERVICE = 11.885, 4.115, 6.40
rng = random.Random(1315)


def odd4(lo, hi):
    """A random whole number in [lo, hi] that is 1 more than a multiple of 4."""
    c = [v for v in range(lo, hi + 1) if v % 4 == 1]
    return rng.choice(c)


def ms_from_mph(mph): return mph / MPH
def m_from_ft(ft): return ft / FT
def m_from_in(i): return i / IN


def ft_value(lo_tenths_or_ft, hi, tenths):
    """A length in ft the app shows odd: below 10 ft with one decimal (tenths 1 mod 4), else whole (1 mod 4)."""
    if tenths:
        return odd4(lo_tenths_or_ft, hi) / 10.0
    return float(odd4(lo_tenths_or_ft, hi))


# ---------------------------------------------------------------------------------------------
# rallies: 31 of them, numbered 1, 3, 5, ...; each an odd number of shots; durations odd seconds
N_RALLIES = 31
lengths = [rng.choice([1, 3, 3, 5, 5, 5, 7, 7, 9, 11]) for _ in range(N_RALLIES)]
lengths[12] = 17                                           # the longest rally
# Chris, 17 Nov: first and second serves. A faulted first serve is a rally of its own (one shot);
# the same server's next rally starts with his second serve (slower, more spin)
for k in (2, 6, 9, 17, 22, 26): lengths[k] = 1
rallies, shots, trajs = [], [], []
t = 31.0
server = 'Player A'
faulted = None                                             # the server whose first serve just faulted
for k, n in enumerate(lengths):
    ridx = 2 * k + 1
    if k == 15: server = 'Player B'                        # second set: the other one serves
    dur = n * 1.3 + 3.0
    dur = float(int(dur) | 1)                              # odd whole seconds
    start = t
    stop = start + dur
    times = [start + 2.0 + i * (dur - 3.0) / max(n, 1) for i in range(n)]
    end = rng.choice(['winner', 'out', 'net']) if n > 1 else rng.choice(['out', 'net'])
    hitter = server
    sides = {'Player A': -1, 'Player B': 1}
    if k % 2: sides = {'Player A': 1, 'Player B': -1}       # ends change
    fast = 0
    second = faulted == server
    faulted = server if (n == 1 and not second) else None
    for i in range(n):
        si = 2 * i + 1                                     # shots numbered 1, 3, 5, ...
        serve = i == 0
        typ = 'serve' if serve else rng.choice(['forehand', 'forehand', 'forehand', 'backhand', 'backhand'])
        side = sides[hitter]
        last = i == n - 1
        call = 'in'
        if last and end in ('out', 'net'): call = end
        # speeds (mph), all 1 mod 4
        sp = (odd4(73, 93) if second else odd4(97, 121)) if serve else (odd4(57, 85) if typ == 'forehand' else odd4(49, 73))
        spb = odd4(int(sp * 0.67), int(sp * 0.77))
        spin = 'topspin'
        if typ == 'backhand' and rng.random() < 0.35: spin = 'slice'
        if serve: spin = rng.choice(['topspin', 'slice']) if second else rng.choice(['topspin', 'flat / low spin'])
        # where it bounces: depth inside the baseline, in ft (whole, 1 mod 4) or out long (tenths)
        if call == 'in':
            # under 10 ft the app shows one decimal: tenths 1 mod 4; from 10 ft whole feet 1 mod 4
            depth_ft = odd4(5, 97) / 10.0 if rng.random() < 0.5 else float(odd4(13, 17))
        elif call == 'out':
            depth_ft = -odd4(5, 41) / 10.0
        else:
            depth_ft = None
        contact = [side * (HALF_L + rng.uniform(-0.6, 1.4)), rng.uniform(-3.5, 3.5), 2.75 if serve else rng.uniform(0.7, 1.2)]
        if depth_ft is not None:
            bx = -side * (HALF_L - m_from_ft(depth_ft))
            lim = 4.0 if not serve else 3.8
            by = rng.uniform(-lim, lim)
            if serve:
                bx = -side * (SERVICE - rng.uniform(0.4, 2.5))   # in the service box
                depth_ft = float(odd4(21, 33))
                bx = -side * (HALF_L - m_from_ft(depth_ft))
                by = (-1 if (k % 2) else 1) * rng.uniform(0.4, 3.6)
            bounce = [round(bx, 3), round(by, 3)]
        else:
            bounce = None
        net_in = odd4(5, 41)                                # net clearance, inches
        apex_ft = odd4(53, 97) / 10.0 if not serve else odd4(89, 97) / 10.0
        launch = (odd4(1, 97) / 10.0) * (-1 if serve else 1)
        spin_ft = odd4(5, 65) / 10.0                       # spin's effect on the bounce
        spin_eff = m_from_ft(-spin_ft if spin != 'slice' else spin_ft)
        top_pct = odd4(57, 97)                              # topspin share; sidespin = 100 - that (odd too)
        top = 0.21 * top_pct / 100.0 * (1 if spin != 'slice' else -1)
        side_sp = 0.21 * (100 - top_pct) / 100.0
        curve = None
        if serve and spin == 'slice':
            # a slice serve spins mostly sideways and curves (Chris, 17 Nov), with a little topspin
            top_pct = odd4(13, 41); top = 0.21 * top_pct / 100.0; side_sp = 0.21 * (100 - top_pct) / 100.0
            curve = m_from_ft(odd4(13, 49) / 10.0)
        rpm = rng.choice([1130, 1370, 1510, 1790, 2010, 2290, 2530]) if spin != 'flat / low spin' else None
        kick = odd4(9, 25)
        conf = odd4(81, 97)
        sd_in = rng.choice([1, 1, 1, 5])
        ft = rng.uniform(0.7, 1.3) if not serve else rng.uniform(0.45, 0.6)
        s = {
            'rally': ridx, 'index': si, 't': round(times[i], 3), 'hitter': hitter, 'hitterTrack': 1 if hitter == 'Player A' else 2,
            'type': typ, 'isServe': serve, 'contact': [round(c, 3) for c in contact],
            'speedContact': ms_from_mph(sp), 'launchDeg': launch, 'directionDeg': rng.uniform(-15, 15),
            'netClearance': m_from_in(net_in), 'apex': m_from_ft(apex_ft), 'flightTime': round(ft, 3),
            'bounce': bounce, 'speedBounce': ms_from_mph(spb) if bounce else None,
            'bounceSd': m_from_in(sd_in) if bounce else None,
            'depth': m_from_ft(depth_ft) if depth_ft is not None else None,
            'call': call, 'margin': 0.31, 'spinEffect': spin_eff if bounce else None, 'spinEffectNet': None,
            'spinTop': top, 'spinSide': side_sp, 'spinCurve': curve if bounce else None, 'CL': abs(top), 'rpm': rpm, 'rpmSd': (rpm * 0.25 if rpm else None),
            'spinLabel': spin, 'kickAngleDeg': float(kick) if bounce else None, 'speedAfter': None, 'speedRatio': None,
            'CD': 0.507, 'fitRmsPx': 0.47, 'confidence': conf / 100.0,
        }
        shots.append(s)
        fast = max(fast, sp)
        hitter = 'Player B' if hitter == 'Player A' else 'Player A'
    rallies.append({'index': ridx, 'start': start, 'stop': stop, 'shots': n, 'duration': dur, 'ending': end,
                    'fastest': ms_from_mph(fast)})
    t = stop + rng.uniform(20, 46)


# ---------------------------------------------------------------------------------------------
# counts the app shows must be odd: shots per hitter (A, B and a few the PC could not tell),
# bounces per filter, shots per spin kind for the first player
def by(key, xs=None):
    d = {}
    for s in (shots if xs is None else xs): d.setdefault(key(s), []).append(s)
    return d


def fix_hitters():
    # three shots the PC could not put a player to ("unknown"), taken so that Player A's and
    # Player B's counts are odd too (A + B + 3 = an odd total)
    nA = sum(s['hitter'] == 'Player A' for s in shots)
    kA = 1 if nA % 2 == 0 else 3 if False else 0
    kA = 1 if nA % 2 == 0 else 0
    kB = 3 - kA if kA == 1 else 3
    if kA == 0: kA, kB = 2, 1
    if (nA - kA) % 2 == 0: kA, kB = (1, 2) if kA != 1 else (3, 0)
    picked = 0
    for p, k in (('Player A', kA), ('Player B', kB)):
        pool = [s for s in shots if s['hitter'] == p and not s['isServe'] and s['call'] == 'in' and s['bounce']]
        for s in pool[5:5 + k]:
            s['hitter'] = 'unknown'; s['hitterTrack'] = 0
fix_hitters()


def odd_counts():
    bad = []
    cnt = lambda xs: len(xs)
    groups = {'total': shots}
    groups.update({'hitter ' + k: v for k, v in by(lambda s: s['hitter']).items()})
    # the court map shows one player at a time (Chris, 17 Nov), starting with Player A (you)
    bounced = [s for s in shots if s['bounce'] and s['hitter'] == 'Player A']
    groups['bounces all'] = bounced
    for ty in ['serve', 'forehand', 'backhand']:
        groups['bounces ' + ty] = [s for s in bounced if s['type'] == ty]
    a = [s for s in shots if s['hitter'] == 'Player A' and s['rpm'] is not None]
    for k, v in by(lambda s: (s['type'], s['spinLabel']), a).items(): groups['spin rows %s' % (k,)] = v
    for name, v in groups.items():
        if cnt(v) % 2 == 0: bad.append((name, cnt(v)))
    return bad


# repair: flip one shot at a time (its spin kind, or drop its rpm, or its bounce) until every count is odd
for _ in range(400):
    bad = odd_counts()
    if not bad: break
    name, _n = bad[0]
    if name.startswith('spin rows'):
        a = [s for s in shots if s['hitter'] == 'Player A' and s['rpm'] is not None]
        ty, lab = eval(name[len('spin rows '):])
        grp = [s for s in a if s['type'] == ty and s['spinLabel'] == lab]
        grp[-1]['rpm'] = None; grp[-1]['rpmSd'] = None
    elif name.startswith('bounces'):
        ty = name.split()[1]
        cands = [s for s in shots if s['bounce'] and s['hitter'] == 'Player A' and (ty == 'all' or s['type'] == ty) and s['call'] == 'in'
                 and s['index'] > 1 and s is not shots[-1]]
        if not cands:   # serves: an ace-less one-shot rally whose serve went out becomes a serve into the net
            one = {r['index'] for r in rallies if r['shots'] == 1}
            cands = [s for s in shots if s['bounce'] and s['hitter'] == 'Player A' and s['type'] == ty and s['rally'] in one]
            for c in cands:
                for r in rallies:
                    if r['index'] == c['rally']: r['ending'] = 'net'
        # the shot that clipped the net cord and dropped: no bounce on the far side counted
        c = cands[len(cands) // 3]
        c['call'] = 'net'; c['bounce'] = None; c['speedBounce'] = None; c['bounceSd'] = None; c['depth'] = None
        c['spinEffect'] = None; c['kickAngleDeg'] = None
    else:
        raise SystemExit('cannot repair ' + name)
assert not odd_counts(), odd_counts()


# per-player "% in" must be odd: in / (in + out + net + too close), rounded
def pct_in(xs):
    called = [s for s in xs if s['call'] in ('in', 'out', 'net', 'too close')]
    return round(100.0 * sum(s['call'] == 'in' for s in called) / len(called)) if called else None


for p in ['Player A', 'Player B', 'unknown']:
    for _ in range(40):
        xs = [s for s in shots if s['hitter'] == p]
        v = pct_in(xs)
        if v is None or v % 2 == 1: break
        # an "in" that was "too close" to call: same bounce, no count changes
        cand = [s for s in xs if s['call'] == 'in' and s['bounce'] and not s['isServe']][0]
        cand['call'] = 'too close'
assert all((pct_in([s for s in shots if s['hitter'] == p]) or 1) % 2 == 1 for p in ['Player A', 'Player B', 'unknown'])
assert not odd_counts(), odd_counts()

# ---------------------------------------------------------------------------------------------
# Chris, 17 Nov: the summary's key figures (his shots: Player A once identified), each against
# the average of the earlier sessions (trend points before this one, below). Every figure shown
# odd: nudge single shots by two in their last shown digit (so each stays odd), or call an "in"
# "too close" (no count changes), until this session's figures and the summary's other numbers are.
def rhu(x): return int(math.floor(x + 0.5))
def mph_s(ms): return str(rhu(ms * MPH))
def ft_s(m):
    # as the app's String.format: Java rounds the shortest decimal form half up (2.15 -> 2.2)
    from decimal import Decimal, ROUND_HALF_UP
    v = m * FT
    return str(Decimal(repr(v)).quantize(Decimal('0.1'), rounding=ROUND_HALF_UP)) if abs(v) < 10 else str(rhu(v))
def odd_s(t): return int(t[-1]) % 2 == 1
def near_tie(x):
    # within a hair of a rounding tie: Kotlin and Python may round it differently, so avoid it
    return abs((x % 1.0) - 0.5) < 0.02
def tie_of(kind, v):
    if v is None: return False
    if kind == 'mph': return near_tie(v * MPH)
    if kind == 'ft':
        x = abs(v * FT); return near_tie(x * 10) if x < 10 else near_tie(x)
    return False
def mean(xs): return sum(xs) / len(xs) if xs else None
def median(xs):
    xs = sorted(xs); n = len(xs)
    return None if n == 0 else (xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2)
CALLED = ('in', 'out', 'net', 'too close')
def pct(xs):
    c = [s for s in xs if s['call'] in CALLED]
    return rhu(100.0 * sum(s['call'] == 'in' for s in c) / len(c)) if c else None


def second_serves():
    # as the app's SessionMetrics.secondServes
    out, faulted = set(), None
    for r in sorted(rallies, key=lambda r: r['start']):
        sh = sorted([s for s in shots if s['rally'] == r['index']], key=lambda s: s['index'])
        if not sh or not sh[0]['isServe']: faulted = None; continue
        sv = sh[0]; is2 = faulted == sv['hitter']
        if is2: out.add(id(sv))
        fault = len(sh) == 1 and sv['call'] in ('out', 'net')
        faulted = sv['hitter'] if fault and not is2 else None
    return out


def serve_kind(s):
    # as the app's serveSpinKind
    if s['spinLabel'].startswith('flat'): return 'flat'
    if s['spinSide'] is not None and s['spinTop'] is not None and abs(s['spinSide']) > abs(s['spinTop']): return 'slice'
    return 'kick' if (s['spinTop'] or 0) >= 0 else 'underspin'


def serve_spin(sv):
    # as the app: the commonest kind; how much shorter (kick, flat) or how far it curved (slice)
    from collections import Counter
    if not sv: return None
    c = Counter(serve_kind(s) for s in sv); top = max(c.values()); k = [x for x in c if c[x] == top][0]
    xs = [s for s in sv if serve_kind(s) == k]
    vals = [abs(s['spinCurve']) for s in xs if s['spinCurve'] is not None] if k == 'slice' else [-s['spinEffect'] for s in xs if s['spinEffect'] is not None]
    return mean(vals)


def serves_of(no):
    sec = second_serves()
    return [s for s in shots if s['hitter'] == 'Player A' and s['isServe'] and ((id(s) in sec) == (no == 2))]


def figures():
    a = [s for s in shots if s['hitter'] == 'Player A']
    rally = [s for s in a if not s['isServe']]; s1 = serves_of(1); s2 = serves_of(2)
    top = lambda ty: mean([-s['spinEffect'] for s in rally if s['type'] == ty and s['spinEffect'] is not None])
    spd = lambda ty: mean([s['speedContact'] for s in rally if s['type'] == ty and s['speedContact'] is not None])
    return {'topspinForehand': top('forehand'), 'topspinBackhand': top('backhand'), 'speedForehand': spd('forehand'),
            'speedBackhand': spd('backhand'),
            'serve1InPct': pct(s1), 'serve1Speed': mean([s['speedContact'] for s in s1]),
            'serve1Spin': serve_spin(s1),
            'serve2InPct': pct(s2), 'serve2Speed': mean([s['speedContact'] for s in s2]),
            'serve2Spin': serve_spin(s2), 'inPct': pct(rally),
            'depth': mean([s['depth'] for s in rally if s['call'] == 'in' and s['depth'] is not None])}


SHOW = {'topspinForehand': ft_s, 'topspinBackhand': ft_s, 'speedForehand': mph_s, 'speedBackhand': mph_s,
        'serve1InPct': str, 'serve1Speed': mph_s, 'serve1Spin': ft_s, 'serve2InPct': str, 'serve2Speed': mph_s, 'serve2Spin': ft_s,
        'inPct': str, 'depth': ft_s}


def shown_ok():
    KIND = {ft_s: 'ft', mph_s: 'mph', str: 'pct'}
    bad = [k for k, v in figures().items() if v is not None and (not odd_s(SHOW[k](v)) or tie_of(KIND[SHOW[k]], v))]
    for p in ['Player A', 'Player B', 'unknown']:        # the summary's other per-player numbers
        xs = [s for s in shots if s['hitter'] == p]
        m = median([s['speedContact'] for s in xs if s['type'] == 'forehand' and s['speedContact'] is not None])
        if m is not None and not odd_s(mph_s(m)): bad.append('median forehand ' + p)
        v = pct(xs)
        if v is not None and v % 2 == 0: bad.append('pct ' + p)
    a = [s for s in shots if s['hitter'] == 'Player A']
    fx = median([s['spinEffect'] for s in a if s['type'] in ('forehand', 'groundstroke') and s['spinEffect'] is not None])
    if fx is not None and not odd_s(ft_s(abs(fx))): bad.append('median forehand spin')
    return bad + [b[0] for b in odd_counts()]


fastest = {r['index']: r['fastest'] for r in rallies}
def nudge(key):
    a = [s for s in shots if s['hitter'] == 'Player A']
    rally = [s for s in a if not s['isServe']]
    serves = serves_of(2) if key.startswith('serve2') else serves_of(1)
    d = rng.choice([-1, 1])
    if key in ('topspinForehand', 'topspinBackhand', 'serve1Spin', 'serve2Spin', 'median forehand spin'):
        ty = {'topspinForehand': 'forehand', 'topspinBackhand': 'backhand', 'median forehand spin': 'forehand'}.get(key)
        pool = [s for s in (serves if key.startswith('serve') else rally) if (ty is None or s['type'] == ty)
                and s['spinEffect'] is not None and 1.0 < abs(s['spinEffect'] * FT) < 9.0]
        curved = [s for s in pool if s['isServe'] and serve_kind(s) == 'slice' and s['spinCurve'] is not None]
        if key.startswith('serve') and curved and rng.random() < 0.5:
            s = rng.choice(curved)
            if s['spinCurve'] * FT < 1.0: d = 1
            if s['spinCurve'] * FT > 9.0: d = -1
            s['spinCurve'] += d * m_from_ft(0.2)
        else:
            s = rng.choice(pool)
            if abs(s['spinEffect'] * FT) > 8.6: d = -1 if s['spinEffect'] < 0 else 1
            s['spinEffect'] -= d * m_from_ft(0.2)
    elif key in ('speedForehand', 'speedBackhand', 'serve1Speed', 'serve2Speed') or key.startswith('median forehand '):
        ty = {'speedForehand': 'forehand', 'speedBackhand': 'backhand'}.get(key, 'forehand')
        hitter = key.replace('median forehand ', '') if key.startswith('median forehand ') else 'Player A'
        src = serves if key.startswith('serve') else shots
        pool = [s for s in src if s['hitter'] == hitter and (s['isServe'] if key.startswith('serve') else (not s['isServe'] and s['type'] == ty))
                and s['speedContact'] is not None and (key.startswith('serve2') or abs(s['speedContact'] - fastest[s['rally']]) > 1e-6)]
        s = rng.choice(pool); s['speedContact'] += d * ms_from_mph(2)
    elif key == 'depth':
        # one decimal below 10 ft: a 0.2 ft step keeps the shot's own figure odd; stay within 0.5-9.5
        pool = [s for s in rally if s['call'] == 'in' and s['depth'] is not None and 0.6 < s['depth'] * FT < 9.4]
        s = rng.choice(pool)
        if s['depth'] * FT < 1.0: d = 1
        if s['depth'] * FT > 9.0: d = -1
        s['depth'] += d * m_from_ft(0.2)
    elif key in ('serve1InPct', 'serve2InPct', 'inPct') or key.startswith('pct '):
        hitter = key[4:] if key.startswith('pct ') else 'Player A'
        src = serves if key.startswith('serve') else [s for s in shots if not s['isServe']]
        pool = [s for s in src if s['hitter'] == hitter and s['call'] == 'in' and s['bounce']]
        rng.choice(pool)['call'] = 'too close'
    else:
        raise SystemExit('no nudge for ' + key)


for _ in range(20000):
    bad = shown_ok()
    if not bad: break
    nudge(rng.choice(bad))
assert not shown_ok(), shown_ok()

# ---------------------------------------------------------------------------------------------
# one flight per shot (Chris, 19 Nov: shot 29.1 was drawn through the net while its card said it
# cleared the net by 17 in and landed in). The numbers above were picked one by one, so a shot's
# net clearance, launch angle, highest point and flight time could contradict its contact point,
# speed and bounce, and the drawn path ignored them. Now each shot is one ballistic flight from its
# contact point to its bounce, as fast as its speed says (drag taken as 15% off the average), and
# the four numbers are read off that flight, each moved to the nearest value the session may show
# (1 more than a multiple of 4 in the shown unit). The flight time is then set so the path crosses
# the net at exactly the clearance shown. Nothing random is drawn here.
NET = 0.914                                                 # the net's height where the app draws it (Court.NET_CENTRE)


def snap4(v):
    """The nearest whole number that is 1 more than a multiple of 4."""
    return int(4 * round((v - 1) / 4.0) + 1)


def apex_shown(m):
    """The nearest height the app can show oddly: tenths of a foot (1 mod 4) under 10 ft, whole
    feet (1 mod 4) from 13 ft."""
    ft = m * FT
    c = [min(snap4(ft * 10), 97) / 10.0] + [float(max(13, snap4(ft)))]
    return m_from_ft(min(c, key=lambda x: abs(x - ft)))


for s in shots:
    p0 = s['contact']; v = s['speedContact']
    if s['bounce']:
        if s['isServe'] and s['depth'] is not None and s['depth'] * FT > 27:
            # a serve cannot clear the net and come down 6 or 10 ft past it: 29 ft short of the
            # baseline becomes 25, 33 becomes 21 (still inside the service box)
            d_ft = 25.0 if s['depth'] * FT < 31 else 21.0
            s['depth'] = m_from_ft(d_ft)
            s['bounce'][0] = round((-1 if p0[0] > 0 else 1) * (HALF_L - s['depth']), 3)
        pb = [s['bounce'][0], s['bounce'][1], R_BALL]
        L = math.hypot(pb[0] - p0[0], pb[1] - p0[1])
        tau = -p0[0] / (pb[0] - p0[0])                       # how far along the flight the net is
        T = L / (0.85 * v)
        if 0.02 < tau < 0.98:
            chord = p0[2] * (1 - tau) + R_BALL * tau; k = 0.5 * G * tau * (1 - tau)
            c_in = max(1 if s['isServe'] else 5, snap4((chord + k * T * T - NET - R_BALL) * IN))
            while NET + R_BALL + m_from_in(c_in) <= chord + k * 0.2 ** 2: c_in += 4    # a flight needs some time
            T = math.sqrt((NET + R_BALL + m_from_in(c_in) - chord) / k)
            s['netClearance'] = m_from_in(c_in)
    else:
        # into the net: the path ends on the net, under the tape, and the clearance is negative
        c_in = -min(snap4(abs(s['netClearance']) * IN), 25)
        s['netClearance'] = m_from_in(c_in)
        pb = [0.0, round(p0[1] * 0.5, 3), NET + R_BALL + m_from_in(c_in)]
        L = math.hypot(pb[0] - p0[0], pb[1] - p0[1])
        T = L / (0.85 * v)
    vz = (pb[2] - p0[2] + 0.5 * G * T * T) / T
    s['flightTime'] = round(T, 3)
    s['launchDeg'] = snap4(math.degrees(math.atan2(vz, L / T)) * 10) / 10.0
    s['apex'] = apex_shown(max(p0[2], pb[2], p0[2] + (vz * vz / (2 * G) if vz > 0 else 0.0)))

# ---------------------------------------------------------------------------------------------
# trajectories: that flight from contact to bounce, then on; and the same launch without spin,
# landing |spin effect| further.
for s in shots:
    p0 = s['contact']
    if s['bounce']:
        pb = [s['bounce'][0], s['bounce'][1], R_BALL]
    else:
        pb = [0.0, round(p0[1] * 0.5, 3), NET + R_BALL + s['netClearance']]     # into the net
    T = s['flightTime']
    def arc(pe, T, extra=0.0):
        vz = (pe[2] - p0[2] + 0.5 * G * T * T) / T
        pts = []
        n = max(2, int(T / 0.01))
        for i in range(n + 1):
            tt = T * i / n
            pts.append([round(p0[0] + (pe[0] - p0[0]) * tt / T, 2), round(p0[1] + (pe[1] - p0[1]) * tt / T, 2),
                        round(max(R_BALL, p0[2] + vz * tt - 0.5 * G * tt * tt), 2)])
        return pts
    xyz = arc(pb, T)
    if s['bounce']:
        d = [pb[0] - p0[0], pb[1] - p0[1]]; L = math.hypot(*d); u = [d[0] / L, d[1] / L]
        for i in range(1, 31):                              # after the bounce
            tt = i * 0.01
            xyz.append([round(pb[0] + u[0] * 12 * tt, 2), round(pb[1] + u[1] * 12 * tt, 2), round(R_BALL + 4 * tt - 0.5 * G * tt * tt, 2)])
        ns = [pb[0] + u[0] * abs(s['spinEffect'] or 0), pb[1] + u[1] * abs(s['spinEffect'] or 0), R_BALL]
        no = arc(ns, T * 1.08)[::2]
    else:
        no = arc(pb, T)[::2]
    trajs.append({'rally': s['rally'], 'shot': s['index'], 't0': s['t'], 'dt': 0.01, 'xyz': xyz, 'noSpin': no, 'dtNoSpin': 0.02})

# ---------------------------------------------------------------------------------------------
# heart rate: a sample every few seconds, rallies higher; every sample odd (17 Nov: each rally's
# highest and lowest readings are shown) and the averages tuned odd. The time-in-zone
# minutes depend on the birth year set on the phone (the max heart rate), so they are not tuned.
end = rallies[-1]['stop'] + 31.0
if round(end / 60.0) % 2 == 0: end += 60.0          # the chart's length in minutes: odd
end = 60.0 * round(end / 60.0)
hr = []
tt = 0.0
gap = (rallies[8]['stop'] + 3, rallies[8]['stop'] + 113)       # one gap over a minute
while tt <= end:
    if not (gap[0] < tt < gap[1]):
        inr = any(r['start'] <= tt <= r['stop'] for r in rallies)
        b = ((139 if inr else 121) + rng.randint(-9, 9)) | 1
        hr.append({'t': round(tt, 1), 'bpm': b})
    tt += rng.choice([3.0, 3.5, 4.5, 5.0])
if hr[-1]['t'] < end: hr.append({'t': end, 'bpm': 119})


def hr_summary(maxgap=60.0):
    p = sorted(hr, key=lambda h: h['t'])
    sAll = wAll = sIn = wIn = sOut = wOut = 0.0
    for i, h in enumerate(p):
        nxt = p[i + 1]['t'] if i + 1 < len(p) else h['t'] + 1.0
        w = max(0.0, min(nxt - h['t'], maxgap))
        wAll += w; sAll += w * h['bpm']
        if any(r['start'] <= h['t'] <= r['stop'] for r in rallies): wIn += w; sIn += w * h['bpm']
        else: wOut += w; sOut += w * h['bpm']
    return int(sAll / wAll), max(h['bpm'] for h in p), int(sIn / wIn), int(sOut / wOut)


for _ in range(400):
    a, mx, i_, o_ = hr_summary()
    if a % 2 and mx % 2 and i_ % 2 and o_ % 2: break
    if mx % 2 == 0:
        top = max(hr, key=lambda h: h['bpm']); top['bpm'] += 2; continue
    # nudge one sample in or out of rallies by one beat
    inr = lambda h: any(r['start'] <= h['t'] <= r['stop'] for r in rallies)
    pool = [h for h in hr if inr(h) == (i_ % 2 == 0)] if (i_ % 2 == 0 or o_ % 2 == 0) else hr
    h = rng.choice(pool)
    if h['bpm'] < mx - 3: h['bpm'] += 2
a, mx, i_, o_ = hr_summary()
assert a % 2 and mx % 2 and i_ % 2 and o_ % 2, (a, mx, i_, o_)
assert all(h['bpm'] % 2 for h in hr)

# ---------------------------------------------------------------------------------------------
# session minutes and the heart-rate chart's minutes must be odd too
span = (rallies[-1]['stop'] - rallies[0]['start']) / 60.0
assert round(span) % 2 == 1, span
assert round(max(rallies[-1]['stop'], hr[-1]['t']) / 60.0) % 2 == 1, end

# ---------------------------------------------------------------------------------------------
session = {
    'synthetic': True, 'spoof': True,
    'note': 'SPOOF session for reviewing the app (Chris, 16 Nov): made-up numbers, none of them even. Not from cameras.',
    'startUtc': '2026-11-15T19:13:00.000Z',
    'air': {'rho': 1.21, 'wind': [ms_from_mph(5) * 0.6, -ms_from_mph(5) * 0.8], 'sessionCD': 0.507,
            'tempC': (61 - 32) * 5 / 9.0},
    'crossing': {'minDeg': 43, 'thresholdDeg': 21, 'low': [], 'text': 'Camera sight lines cross at 43 deg or more everywhere on court.'},
    'identity': {'chrisTrack': 0, 'confidence': [0.83, 0.83], 'question': True},
    'counts': {'rallies': len(rallies), 'shots': len(shots)},
    'rejects': {'report': 'rejects/rejects.html', 'csv': 'rejects/rejects.csv',
                'counts': [{'reason': 'mostly outside', 'n': 341}, {'reason': 'isolated', 'n': 113},
                           {'reason': 'epipolar fail (kept, one camera)', 'n': 57}, {'reason': 'person off court', 'n': 3},
                           {'reason': 'implausible flight', 'n': 1}]},
}

# trends: seventeen made-up sessions, the last on this session's day (16 earlier: more than the
# ten the summary's second average takes); every value odd, so the charts' labels (lowest and
# highest value) are too
trend = {'synthetic': True, 'note': 'SPOOF trend: made-up numbers, none of them even.', 'sessions': []}
N_TREND = 17
for i in range(N_TREND):
    k = N_TREND - 1 - i
    trend['sessions'].append({'epochDay': 20772 - 3 * k - (k % 3), 'forehandSpinEffect': -m_from_ft(odd4(53, 97) / 10.0),
                              'forehandDepth': m_from_ft(odd4(41, 89) / 10.0), 'shots': odd4(101, 197)})


# key figures of the earlier sessions (every trend point before this session's day): each
# value shown odd, and their averages (what the summary compares with) odd too
RANGES = {'topspinForehand': ('ft', 33, 77), 'topspinBackhand': ('ft', 13, 49), 'speedForehand': ('mph', 53, 77),
          'speedBackhand': ('mph', 45, 69), 'serve1InPct': ('pct', 49, 77), 'serve1Speed': ('mph', 97, 117),
          'serve1Spin': ('ft', 9, 41), 'serve2InPct': ('pct', 77, 97), 'serve2Speed': ('mph', 73, 89),
          'serve2Spin': ('ft', 29, 65), 'inPct': ('pct', 61, 89), 'depth': ('ft', 45, 89)}
def hist_value(kind, lo, hi):
    v = odd4(lo, hi)
    return m_from_ft(v / 10.0) if kind == 'ft' else ms_from_mph(v) if kind == 'mph' else v
earlier = [p for p in trend['sessions'] if p['epochDay'] < 20772]
for p in earlier:
    p['metrics'] = {k: hist_value(*r) for k, r in RANGES.items()}
def avg_shown(k, last=None):
    vals = [p['metrics'][k] for p in (earlier[-last:] if last else earlier)]
    kind = RANGES[k][0]
    if tie_of(kind, sum(vals) / len(vals)): return '0'
    if kind == 'pct': return str(rhu(sum(vals) / len(vals)))
    return ft_s(sum(vals) / len(vals)) if kind == 'ft' else mph_s(sum(vals) / len(vals))
# both averages the summary shows (Chris, 17 Nov): all earlier sessions, and the last ten
assert len(earlier) > 10, len(earlier)
for k, (kind, lo, hi) in RANGES.items():
    step = m_from_ft(0.2) if kind == 'ft' else ms_from_mph(2) if kind == 'mph' else 2
    for _ in range(2000):
        if odd_s(avg_shown(k, 10)) and odd_s(avg_shown(k)): break
        pool = earlier[-10:] if not odd_s(avg_shown(k, 10)) else earlier[:-10]
        rng.choice(pool)['metrics'][k] += rng.choice([-1, 1]) * step
    assert odd_s(avg_shown(k, 10)) and odd_s(avg_shown(k)), k

# ball check: an odd number of frames
checks = json.load(open(os.path.join(OUT, 'checks.json')))
checks['checks'] = checks['checks'][:19]
checks['note'] = 'SPOOF: 19 frames'

with open(os.path.join(OUT, 'session.json'), 'w') as f: json.dump(session, f)
with open(os.path.join(OUT, 'shots.json'), 'w') as f: json.dump(shots, f)
with open(os.path.join(OUT, 'rallies.json'), 'w') as f: json.dump(rallies, f)
with open(os.path.join(OUT, 'trajectories.json'), 'w') as f: json.dump(trajs, f)
with open(os.path.join(OUT, 'hr.json'), 'w') as f: json.dump(hr, f)
with open(os.path.join(OUT, 'trends.json'), 'w') as f: json.dump(trend, f)
with open(os.path.join(OUT, 'checks.json'), 'w') as f: json.dump(checks, f)
print('%d rallies, %d shots; hitters %s; HR avg %d max %d' % (len(rallies), len(shots),
      {k: len(v) for k, v in by(lambda s: s['hitter']).items()}, a, mx))
