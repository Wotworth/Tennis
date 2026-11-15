-- Court conditions from the app (Chris, 15 Nov): only an indoor flag per session.
-- Court names and photos stay on the phone; this table has no room for them.
CREATE TABLE session_conditions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  indoor INTEGER NOT NULL,
  answered_utc TEXT NOT NULL,
  applied INTEGER NOT NULL DEFAULT 0
);
