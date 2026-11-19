#!/bin/bash
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; M=/home/user/private-footage/ml
while ! grep -q "round 4 all done" orch_r4.log; do sleep 20; done
export MODEL_IN=grey
PRE=$M/net_pre4.pt ../tv-ml/bin/python eval_windows.py $M/net_r4.pt r4p > eval_r4p.log 2>&1
echo "cascade scored $(date +%T)"
