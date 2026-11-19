"""Path pictures for the private review document: build_review.py V TAG  (frames stay out of the repo).
Run once per video (the GoPro needs VIDEO_W, VIDEO_H in the environment)."""
import sys, os, glob, json
import common, review_img

STRETCH = {6: [(14410, 14559), (15460, 15609), (15160, 15309), (15610, 15759)],
           7: [(16475, 16624), (15861, 16010), (17152, 17301), (16700, 16849)],
           5: [(25504, 25653), (25654, 25795), (9154, 9303), (9454, 9595)]}
FILES = {6: 'v6_p02[456].npy', 7: 'v7_p05[2345].npy', 5: 'v5_p00[89].npy'}
NAME = {6: 'iPhone match', 7: 'SwingVision clip', 5: 'GoPro Hero 7'}

v, tag = int(sys.argv[1]), sys.argv[2]
out = '/tmp/claude-0/scratchpad/review/doc'; os.makedirs(out, exist_ok=True)
files = sorted(glob.glob(f'{common.ROOT}/ml/pts_{tag}/{FILES[v]}'))
ball = review_img.in_play(files)
info = {}
for a, b in STRETCH[v]:
    n = review_img.path_picture(v, ball, a, b, f'{out}/path_v{v}_{a}_{tag}.jpg',
                                f'{NAME[v]}, frames {a} to {b} ({(b - a + 1) / 60:.1f} s): ball tracked in %d of {b - a + 1}' %
                                sum(1 for f in range(a, b + 1) if f in ball), width=1280)
    info[a] = n
json.dump(info, open(f'{out}/path_v{v}_{tag}.json', 'w'))
print(v, tag, info)
