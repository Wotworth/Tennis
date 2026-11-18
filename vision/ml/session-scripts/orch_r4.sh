#!/bin/bash
# round 4 (resumable: each step is skipped when its result exists)
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; PY=../tv-ml/bin/python; M=/home/user/private-footage/ml
EX="$M/mine/v{v}_*_mine4.npz;$M/mine_r2/v{v}_*_mine4.npz;$M/mine_r3/v{v}_*_mine4.npz"
for d in mine mine_r2 mine_r3; do MINE_SUFFIX=_mine4 $PY mine2.py "$M/$d/*.npy" >> mine2_r4_$d.log 2>&1; done
echo "mined $(date +%T)"
one() {   # tag, MODEL_IN
  export MODEL_IN=$2
  [ -f $M/net_$1.pt ] || POS=pos4 OLDNEG=0 MINED_NEG=0.7 EXTRA="$EX" $PY train.py all 6 $M/net_$1.pt > train_$1.log 2>&1
  echo "$1 trained $(date +%T)"
  $PY eval_windows.py $M/net_$1.pt $1 > eval_$1.log 2>&1
  $PY val_windows.py $M/net_$1.pt $1 > val_$1.log 2>&1
  echo "$1 scored $(date +%T)"
  ./stress.sh $M/net_$1.pt $1 > stress_$1.log 2>&1
  echo "$1 stress done $(date +%T)"
}
one r4 grey
one r4c hint
echo "round 4 all done $(date +%T)"
