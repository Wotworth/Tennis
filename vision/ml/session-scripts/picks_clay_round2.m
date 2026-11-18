% clay video, learned detector round 2 (ballnet_v2, 18 Nov): sample frames for the app and the check's counts
P = {
  1, 240,   'no ball', 'between points: a ball lying on the court is not ringed'
  1, 1485,  'no ball', 'between points: nothing ringed'
  4, 5496,  'no ball', 'the far player waiting: nothing ringed'
  6, 9493,  'found',   'the ball reaching the far player''s forehand, ringed'
  6, 10071, 'no ball', 'between points: nothing ringed'
  6, 10605, 'no ball', 'the far player getting ready to serve: nothing ringed'
  8, 13511, 'found',   'the serve toss: the ball ringed at the top'
 11, 18913, 'no ball', 'between points: nothing ringed'
 12, 20294, 'no ball', 'no ball in flight; the ring by the net is a false spot'
 12, 21252, 'missed',  'the ball by the far player is missed; the ring is on the curtain'
};
picks = struct('clip', P(:, 1), 'frame', P(:, 2), 'verdict', P(:, 3), 'caption', P(:, 4));
check = struct('framesChecked', 10, 'ballVisible', 3, 'found', 2, 'missed', 1, 'spotsChecked', 12, 'spotsBall', 9, ...
  'note', 'Round-2 detector: 9 of 12 tracked spots are balls (2 of them on the next court, seen through the divider net); the other 3 are a shirt logo, the net and the curtain. In the 10 sample frames the ball was in flight in 3: found in 2. Balls lying on the court are never ringed.');
notes = {
 'One camera (an iPhone, unedited SwingVision recording, indoor clay). 6 minutes from the middle of the session (36-42 min).'
 'Re-run on 18 Nov with the round-2 ball detector: small moving spots found without colour, a small learned classifier trained on your three videos and the rest of this recording (no hand labels), and smooth paths through time with one ball in play. Nothing was set for this court or its light.'
 'On the fixed test set (your three videos, 48 frames) it found 30 of 34 balls with no false spots; the old colour detector found 15 with 63.'
 'The court was found from its tape lines alone: 99% of the fitted lines lie on paint. All four near corners are out of view.'
 'Your drawing was on a frame from the first minute; the phone had moved 35 px across and 19 px up by then, which was allowed for when scoring.'
 'Points (14) are found from the ball paths. A point now ends where the ball is bounced on the spot (the server before the next serve) and must hold a bounce in play; the next court''s ball no longer joins points together.'
 'Bounces: 56 in play are shown. Left out of the 144 turns found: 36 bounced on the spot or with too little track to tell, 37 on the next courts, 10 in the air (hits), 5 between rallies.'
 'One camera behind the baseline cannot always tell how far a ball flying straight away from it has come, so a few far-end bounces in play are left out. Two cameras measure that directly.'
 'People are no longer pixelated in the sample frames (you have permission for this video), so you can zoom in on any ring.'
};
