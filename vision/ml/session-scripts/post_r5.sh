#!/bin/bash
# after a round-5 model is scored: numbers and pictures for the review.  post_r5.sh TAG
cd /tmp/claude-0/scratchpad/ml; export PYTHONPATH=$PWD; PY="nice -n 5 ../tv-ml/bin/python"; M=/home/user/private-footage/ml; T=$1
R=/tmp/claude-0/scratchpad/review
{
echo "== test set"; $PY rescore.py r4 $T 2>&1 | grep -v "^$" | tail -12
echo "== check set"; $PY valscore.py r4s $T 2>&1 | tail -8
echo "== shadow share, held-out stretches"
$PY newscore.py 6 "$M/pts_$T/v6_p02[456].npy" 2>&1 | tail -1
$PY newscore.py 7 "$M/pts_$T/v7_p05[2345].npy" 2>&1 | tail -1
VIDEO_W=2704 VIDEO_H=2028 $PY newscore.py 5 "$M/pts_$T/v5_p00[89].npy" 2>&1 | tail -1
} > post_$T.log 2>&1
$PY build_review.py 6 $T >> post_$T.log 2>&1
$PY build_review.py 7 $T >> post_$T.log 2>&1
VIDEO_W=2704 VIDEO_H=2028 $PY build_review.py 5 $T >> post_$T.log 2>&1
$PY eyesheet.py 6 12 $R/eye_v6_$T.png "$M/pts_$T/v6_p02[456].npy" 7 2>&1 | tail -2 >> post_$T.log
$PY eyesheet.py 7 12 $R/eye_v7_$T.png "$M/pts_$T/v7_p05[2345].npy" 7 2>&1 | tail -2 >> post_$T.log
VIDEO_W=2704 VIDEO_H=2028 $PY eyesheet.py 5 12 $R/eye_v5_$T.png "$M/pts_$T/v5_p00[89].npy" 7 2>&1 | tail -2 >> post_$T.log
echo "post $T done $(date -u +%T)" >> post_$T.log
