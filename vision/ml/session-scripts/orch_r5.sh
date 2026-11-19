#!/bin/bash
# Round 5 (19 Nov, overnight): new footage mined, drawn shadows, the colour-change input; resumable
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; PY=../tv-ml/bin/python; M=/home/user/private-footage/ml; O=/home/user/private-footage/overlay
while ! grep -q "v7 done" chain_new.log; do sleep 30; done
# 1. weak labels where there is an overlay, then mining (training stretches only)
[ -f $M/weak_v7.npz ] || $PY mine_weak.py 7 $O $M/pts_r4 $M/weak_v7.npz > weak_v7.log 2>&1
VIDEO_W=2704 VIDEO_H=2028 $PY mine5.py 5 $O $M/pts_r4 > mine5_v5.log 2>&1
TRAIN_UNTIL=12000 $PY mine5.py 6 $O $M/pts_r4 > mine5_v6.log 2>&1
TRAIN_UNTIL=9000 $PY mine5.py 7 $O $M/pts_r4 $M/weak_v7.npz > mine5_v7.log 2>&1
echo "mined $(date -u +%T)"
# 2. drawn balls on the new courts, and drawn shadows on every court with a fitted camera
gen() { [ -f $M/data/$4 ] || FRAME_MAX=$5 POSONLY=$2 SHADOWS=$3 $PY gen_data.py $1 $6 90 $M/data/$4 > /dev/null 2>&1; }
( gen 6 75 0 pos4_v6_s1.npz 12000 11 & gen 6 75 0 pos4_v6_s2.npz 12000 12 & gen 7 75 0 pos4_v7_s1.npz 9000 13 & gen 7 75 0 pos4_v7_s2.npz 9000 14 & wait )
( gen 1 0 30 shd5_v1_s1.npz 999999999 21 & gen 2 0 30 shd5_v2_s1.npz 999999999 22 & gen 3 0 30 shd5_v3_s1.npz 999999999 23 & gen 6 0 30 shd5_v6_s1.npz 12000 24 & wait )
( gen 7 0 30 shd5_v7_s1.npz 9000 25 & gen 4 0 30 shd5_v4_s1.npz 999999999 26 & wait )
echo "drawn $(date -u +%T)"
EX="$M/mine/v{v}_*_mine4.npz;$M/mine_r2/v{v}_*_mine4.npz;$M/mine_r3/v{v}_*_mine4.npz;$M/pts_r4/v{v}_*_mine5.npz;$M/data/shd5_v{v}_*.npz"
one() {   # tag, MODEL_IN, INV
  export MODEL_IN=$2 INV=$3
  [ -f $M/net_$1.pt ] || POS=pos4 OLDNEG=0 MINED_NEG=0.6 EXTRA="$EX" $PY train.py v1234567 5 $M/net_$1.pt > train_$1.log 2>&1
  echo "$1 trained $(date -u +%T)"
  PRE=$M/net_pre4.pt $PY eval_windows.py $M/net_$1.pt $1 > eval_$1.log 2>&1
  PRE=$M/net_pre4.pt $PY val_windows.py $M/net_$1.pt $1 > val_$1.log 2>&1
  echo "$1 scored $(date -u +%T)"
  # the held-out stretches of the new footage
  WEIGHTS=$M/net_$1.pt PRE=$M/net_pre4.pt STEP=1 WORKERS=4 FROM=14400 UNTIL=16200 $PY detect_points.py 6 $O $M/pts_$1 > new_$1.log 2>&1
  WEIGHTS=$M/net_$1.pt PRE=$M/net_pre4.pt STEP=1 WORKERS=4 FROM=15600 UNTIL=18000 $PY detect_points.py 7 $O $M/pts_$1 >> new_$1.log 2>&1
  VIDEO_W=2704 VIDEO_H=2028 WEIGHTS=$M/net_$1.pt PRE=$M/net_pre4.pt STEP=1 WORKERS=4 USE=test $PY detect_points.py 5 $O $M/pts_$1 >> new_$1.log 2>&1
  echo "$1 new footage done $(date -u +%T)"
  CONDS="plain grey warm dark invert" ./stress.sh $M/net_$1.pt $1 > stress_$1.log 2>&1
  echo "$1 stress done $(date -u +%T)"
}
one r5 chroma 1
one r5n grey 0
echo "round 5 all done $(date -u +%T)"
