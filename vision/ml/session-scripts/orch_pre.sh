#!/bin/bash
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; M=/home/user/private-footage/ml
while ! grep -q "r4c trained" orch_r4.log; do sleep 30; done
THREADS=2 POS=pos4 OLDNEG=0 MINED_NEG=0.7 EXTRA="$M/mine/v{v}_*_mine4.npz;$M/mine_r2/v{v}_*_mine4.npz;$M/mine_r3/v{v}_*_mine4.npz" nice -n 5 ../tv-ml/bin/python train_pre.py 4 $M/net_pre4.pt > train_pre4.log 2>&1
echo "pre done $(date +%T)"
