-- Tennis Vision database (TV-API-02). Health data is never stored here (Chris, 15 Nov):
-- heart rate stays on the phone, so there is no health table.
CREATE TABLE courts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  indoor INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE cameras (
  serial TEXT PRIMARY KEY,
  role TEXT NOT NULL
);
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,                 -- set by the PC, e.g. 2026-11-14T150000Z_home
  start_utc TEXT NOT NULL,
  court_id TEXT,
  duration_s REAL,
  shot_count INTEGER,
  rally_count INTEGER,
  headline TEXT,                       -- one line for the list (TV-APP-01)
  mode TEXT NOT NULL DEFAULT 'full',   -- 'full' or 'reduced' (one camera, TV-ING-21)
  identity_pending INTEGER NOT NULL DEFAULT 0,  -- TV-PLY-07: kept out of trends until answered
  summary_json TEXT,                   -- session.json as the PC wrote it
  status TEXT NOT NULL DEFAULT 'uploading',     -- shows in the app only when 'ready' (TV-UP-02)
  updated_utc TEXT
);
CREATE TABLE rallies (
  session_id TEXT NOT NULL,
  idx INTEGER NOT NULL,
  start_s REAL, stop_s REAL, shots INTEGER, duration_s REAL, ending TEXT, fastest REAL,
  PRIMARY KEY (session_id, idx)
);
CREATE TABLE shots (
  session_id TEXT NOT NULL,
  rally INTEGER NOT NULL,
  idx INTEGER NOT NULL,
  t REAL, hitter TEXT, type TEXT, is_serve INTEGER,
  speed_contact REAL, speed_bounce REAL, speed_after REAL,
  launch_deg REAL, direction_deg REAL,
  contact_x REAL, contact_y REAL, contact_z REAL,
  net_clearance REAL, apex REAL, flight_time REAL,
  bounce_x REAL, bounce_y REAL, bounce_sd REAL, depth REAL,
  call TEXT, margin REAL,
  spin_effect REAL, spin_effect_net REAL, spin_top REAL, spin_side REAL,
  rpm REAL, rpm_sd REAL, spin_label TEXT,
  kick_angle REAL, speed_ratio REAL, cd REAL, fit_rms REAL, confidence REAL,
  PRIMARY KEY (session_id, rally, idx)
);
CREATE INDEX shots_session ON shots(session_id);
CREATE INDEX shots_hitter ON shots(hitter);
CREATE INDEX shots_type ON shots(type);
-- per-session figures the PC computed (TV-MET-02); trends only read them (TV-API-01)
CREATE TABLE session_stats (
  session_id TEXT NOT NULL,
  shot_type TEXT NOT NULL,
  metric TEXT NOT NULL,
  median REAL, iqr REAL, n INTEGER,
  PRIMARY KEY (session_id, shot_type, metric)
);
CREATE TABLE processing_runs (
  session_id TEXT NOT NULL,
  code TEXT, started_utc TEXT, finished_utc TEXT, seconds REAL
);
-- "Which one is you?" answers from the app (TV-API-04); the PC applies them
CREATE TABLE identity_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  stretch INTEGER NOT NULL DEFAULT 0,
  label TEXT NOT NULL,                 -- the player label Chris tapped, e.g. 'Player A'
  answered_utc TEXT NOT NULL,
  applied INTEGER NOT NULL DEFAULT 0
);
