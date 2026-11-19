-- Court corners (Chris, 19 Nov; TV-CAL-21, TV-CAL-22). When the court-line fit of a camera is
-- doubtful the PC holds the session and posts that camera's picture of the empty court (R2:
-- sessions/<id>/calibration/cam<k>.jpg) with the fitted lines. In the app Chris taps the four
-- corners of the doubles court, or says the drawn lines are right. The PC pulls the answer and
-- runs the session on. The Worker stores and lists, and computes nothing.
CREATE TABLE calibration_checks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  cam INTEGER NOT NULL,              -- 1 or 2
  picture_path TEXT NOT NULL,        -- path of the picture within the session's files
  width INTEGER NOT NULL, height INTEGER NOT NULL,   -- the sent picture, px
  scale REAL NOT NULL,               -- sent-picture px per px of the camera's full picture
  support REAL,                      -- share of the fitted lines with paint under them (0 to 1)
  reason TEXT NOT NULL,              -- 'lines' (the lines do not back the fit) or 'taps' (the last taps did not make a court)
  lines TEXT NOT NULL,               -- JSON: the fitted court's lines, each a list of [x, y] in the sent picture
  created_utc TEXT NOT NULL,
  answer TEXT,                       -- 'corners' or 'accepted'
  corners TEXT,                      -- JSON: four [x, y] in the sent picture's pixels, from its top-left corner
  answered_utc TEXT,
  applied INTEGER NOT NULL DEFAULT 0,
  UNIQUE (session_id, cam)
);
