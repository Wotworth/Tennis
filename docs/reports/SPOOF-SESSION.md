# The sample (spoof) session

The app's bundled sample vision session is made up by `app/spoof/make_spoof_session.py` (Chris, 16 Nov): no even number anywhere it shows, so an even number on a vision screen did not come from the session (`SpoofOddNumbersTest`).

## One flight per shot (19 Nov)

Chris: shot 29·1's picture showed the ball going through the net while its card said it cleared the net by 17 in and landed in. The spoof picked each shot's net clearance, launch angle, highest point and flight time one by one, and the drawn path was a plain arc that ignored them, so they could contradict each other and the contact point, speed and bounce (in 120 of 169 shots the path's height at the net was more than 0.25 m from the clearance shown).

Now each shot is one ballistic flight from its contact point to its bounce, as fast as its speed says, and those four numbers are read off that flight, each moved to the nearest value the session may show (1 more than a multiple of 4 in the shown unit). The flight time is set so the path crosses the net at exactly the clearance shown. A serve shown 29 or 33 ft short of the baseline (6 to 10 ft past the net, which no serve over the net can do) becomes 25 or 21 ft. A net ball's path ends on the net under the tape, and its clearance is negative. Nothing else about the session changed.

Test: `SamplePathsTest` (every drawn path crosses the net at the clearance on its card; no "in" or "out" path under the tape; every net ball ends on the net). The real pipeline cannot disagree this way: it reads the clearance off the fitted flight itself (`tv.metrics.shot`).
