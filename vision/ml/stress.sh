#!/bin/bash
# the classifier alone at each test frame under each stress condition: $1 weights, $2 tag
cd "$(dirname "$0")"; export PYTHONPATH=$PWD; PY=${PY:-python3}
for c in plain grey hue dark invert warm; do
  COND=$c $PY quickscore.py $1 ${2}_${c}q > /dev/null 2>&1
  $PY - <<PYEOF
import numpy as np, common
L = common.labels()
for thr in (0.5,):
    d = {}; top = 0; nb = 0
    for (v, i), lab in L.items():
        D = np.load(f'{common.ROOT}/ml/win/${2}_${c}q_v{v}_i{i:02d}.npy'); D = D[D[:, 0] == lab['frame']] if len(D) else np.zeros((0, 11))
        d[(v, i)] = [(r[1], r[2]) for r in D[D[:, 3] > thr]]
    s = common.score(d)
    print('%-7s score > %.1f: ' % ('$c', thr) + '  '.join('v%s %d/%d f%d' % (k, s[k]['found'], s[k]['balls'], s[k]['false']) for k in (1, 2, 3, 'all')))
PYEOF
done
