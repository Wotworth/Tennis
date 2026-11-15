-- Detector improvement loop and opponents (Chris, 15 Nov). The app posts, the PC pulls;
-- the Worker stores and lists, and computes nothing.

-- "Ball check": crops the PC uploads (R2: sessions/<id>/checks/<frame>.jpg) and Chris's taps
CREATE TABLE ball_checks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  frame_ref TEXT NOT NULL,           -- the PC's own key for the frame (camera, frame number)
  crop_path TEXT NOT NULL,           -- path of the crop within the session's files
  pred_x REAL, pred_y REAL,          -- the detector's ball, in crop pixels (null: no ball predicted)
  width INTEGER NOT NULL, height INTEGER NOT NULL,
  created_utc TEXT NOT NULL,
  answer TEXT,                       -- 'ok', 'moved', 'none'
  ans_x REAL, ans_y REAL,            -- for 'moved': where the ball really is (crop pixels)
  answered_utc TEXT,
  applied INTEGER NOT NULL DEFAULT 0,
  UNIQUE (session_id, frame_ref)
);

-- "This looks wrong" on a shot, and "Missed a shot here" in a rally
CREATE TABLE flags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  kind TEXT NOT NULL,                -- 'looks wrong' or 'missed shot'
  rally INTEGER,
  shot INTEGER,
  reason TEXT,                       -- looks wrong: 'wrong speed', 'wrong call', 'not my shot', 'not a real shot'
  t REAL,                            -- missed shot: seconds into the session
  created_utc TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',   -- 'open', 'applied' (the PC dealt with it), 'reviewed'
  note TEXT                          -- what the PC did, e.g. 'added shot 4.31 s'
);

-- Opponents: names live only here (never in Git, fixtures or logs)
CREATE TABLE opponents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  created_utc TEXT NOT NULL
);
CREATE TABLE session_opponents (
  session_id TEXT PRIMARY KEY,
  opponent_id INTEGER,               -- null: skipped / unknown
  answered_utc TEXT NOT NULL
);

-- per-session figures by player (the PC computes them): 'chris' or 'opponent'.
-- SQLite cannot change a primary key, so the table is rebuilt with the player in it.
CREATE TABLE session_stats_new (
  session_id TEXT NOT NULL,
  player TEXT NOT NULL DEFAULT 'chris',
  shot_type TEXT NOT NULL,
  metric TEXT NOT NULL,
  median REAL, iqr REAL, n INTEGER,
  PRIMARY KEY (session_id, player, shot_type, metric)
);
INSERT INTO session_stats_new (session_id, player, shot_type, metric, median, iqr, n)
  SELECT session_id, 'chris', shot_type, metric, median, iqr, n FROM session_stats;
DROP TABLE session_stats;
ALTER TABLE session_stats_new RENAME TO session_stats;
