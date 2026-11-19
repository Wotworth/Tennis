"""Group the words and digits of one or more scanned exports; draw one example of each group."""
import overlay as O, numpy as np, pickle, sys
from PIL import Image, ImageDraw
words_c, digit_c = [], []      # clusters: [mask, count, example (tag, frame)]
def add(cl, m, where):
    for c in cl:
        if O.same(c[0], m): c[1] += 1; return
    cl.append([m, 1, where])
for tag in sys.argv[1:]:
    r, dots, words, speed, colour = pickle.load(open(f'{tag}_scan.pkl', 'rb'))
    R = O.regions(r)
    for a, b, name in O.states(words, speed, colour):
        for y0, x0, m in O.text_lines(O.majority(words, a, b, R['words'])): add(words_c, m, (tag, a))
        L = O.text_lines(O.majority(speed, a, b, R['speed']))
        if L:
            for x0, g in O.glyphs(L[0][2]): add(digit_c, g, (tag, a))
            if len(L) > 1: add(words_c, L[1][2], (tag, a))
pickle.dump((words_c, digit_c), open('clusters.pkl', 'wb'))
for nm, cl in (('words', words_c), ('digits', digit_c)):
    cl.sort(key=lambda c: -c[1])
    H = sum(c[0].shape[0] + 6 for c in cl) + 4; W = max(c[0].shape[1] for c in cl) + 150
    im = Image.new('L', (W, H), 0); d = ImageDraw.Draw(im); y = 2
    for i, c in enumerate(cl):
        im.paste(Image.fromarray((c[0] * 255).astype(np.uint8)), (4, y))
        d.text((c[0].shape[1] + 12, y), f'#{i} x{c[1]} {c[2][0]}@{c[2][1]}', fill=255)
        y += c[0].shape[0] + 6
    im = im.resize((W * 2, H * 2), Image.NEAREST); im.save(f'clusters_{nm}.png')
    print(nm, len(cl), [c[1] for c in cl])
