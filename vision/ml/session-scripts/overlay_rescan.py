import overlay as O, pickle, sys
for tag in sys.argv[1:]:
    r, _ = O.court_rect(tag); out = O.scan(tag, r); pickle.dump((r,) + out, open(f'{tag}_scan.pkl', 'wb')); print(tag, 'scanned', flush=True)
