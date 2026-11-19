#!/bin/bash
# rounds 4 and 5 on the same fresh SwingVision bounce marks (minutes 6 to 12 of the export; never trained on)
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; PY=../tv-ml/bin/python; M=/home/user/private-footage/ml; O=/home/user/private-footage/overlay


echo "overlay read $(date -u +%T)" >> miss8.log
mkdir -p $M/pts8_r4 $M/pts8_r5
UNTIL=10600 STEP=1 WORKERS=3 MODEL_IN=grey WEIGHTS=$M/net_r4.pt PRE=$M/net_pre4.pt $PY detect_points.py 8 $O $M/pts8_r4 > det8_r4.log 2>&1
echo "r4 detected $(date -u +%T)" >> miss8.log
UNTIL=10600 STEP=1 WORKERS=3 MODEL_IN=chroma WEIGHTS=$M/net_r5.pt PRE=$M/net_pre4.pt $PY detect_points.py 8 $O $M/pts8_r5 > det8_r5.log 2>&1
echo "r5 detected $(date -u +%T)" >> miss8.log
for t in r4 r5; do echo "== $t" >> miss8.log; $PY mine_weak.py 8 $O $M/pts8_$t /tmp/claude-0/scratchpad/h4/w8_$t.npz >> miss8.log 2>&1; done
echo "miss8 done $(date -u +%T)" >> miss8.log
