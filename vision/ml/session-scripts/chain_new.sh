#!/bin/bash
# overnight 19 Nov: detector (round 4, first pass) over the new footage, one video after another
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD MODEL_IN=grey STEP=1 WORKERS=4; M=/home/user/private-footage/ml; O=/home/user/private-footage/overlay
export WEIGHTS=$M/net_r4.pt PRE=$M/net_pre4.pt
FROM=14400 UNTIL=16200 nice -n 5 ../tv-ml/bin/python detect_points.py 6 $O $M/pts_r4 > detect_v6b.log 2>&1
echo "v6 done $(date -u +%T)"
VIDEO_W=2704 VIDEO_H=2028 nice -n 5 ../tv-ml/bin/python detect_points.py 5 $O $M/pts_r4 > detect_v5pts.log 2>&1
echo "v5 done $(date -u +%T)"
UNTIL=9000 nice -n 5 ../tv-ml/bin/python detect_points.py 7 $O $M/pts_r4 > detect_v7.log 2>&1
FROM=15600 UNTIL=18000 nice -n 5 ../tv-ml/bin/python detect_points.py 7 $O $M/pts_r4 >> detect_v7.log 2>&1
echo "v7 done $(date -u +%T)"
