# Part F: racquets, sessions and mid-session switches (16 Nov). Not implemented; for Chris's approval.

Chris's message was cut off partway through Part F ("…to see whether performance dr…"). This covers the questions that arrived and a design for racquet switches. The rest of Part F, including fatigue, is waiting for the full text.

## 1. Answers: what the current design does

**Is every session tied to the racquet, with its string setup at the time?**
- **Logged sessions** (manual, or detected from Health Connect): yes.
  - Each has its racquet (`session_racquets`; one racquet per session since 6 Nov).
  - The string setup is the racquet's latest restring on or before the session's date: string type, gauge, tension, hybrid, restring date. The app derives it; it doesn't copy it into the session.
- **Vision sessions** (the cameras): **no, not yet.**
  - The spec asks for it (TV-HC-05: link the vision session to the matching logged session and the racquet in use, asking once if unclear; TV-MET-03: trends linked to racquet, string, tension and days since restring).
  - It is not built. The app's vision trends today are the spoof/synthetic sample, with the selected racquet's restrings drawn as markers.
- **Shots:** not tied to a racquet. A shot belongs to a vision session; once that session is linked, all its shots inherit one racquet. There is no way yet to switch racquets mid-session.

**Can I compare stats across racquets, string setups and string age?**
- Specified (TV-MET-03, TV-APP-06), not built.
- The app compares racquets today only on the logged sessions' own measures (hours, feel, heart rate), not on vision stats such as depth, spin effect, serve speed or placement.

## 2. Design: racquet per shot, with mid-session switches

**Principle:** which racquet was in Chris's hand is decided on the phone and stays on the phone, like court names (section A item 11). The PC never needs it.
- The app joins its own racquet log to the shots it downloads.
- No racquet name or string detail leaves the phone.

### 2.1 Before the session: the starting racquet
- The **court session** screen (or the launcher tile's "court" action) has **Start**.
  - Start asks one question: "Starting with:" and the racquets, most recently used first. One tap.
  - It writes a **racquet log** entry: (start time, racquet), with the phone's clock in UTC.
- If Chris forgets to tap Start, the app uses the racquet of the logged session that overlaps in time, or else asks once when the vision session arrives ("Which racquet did you start with?").

### 2.2 During the session: logging a switch
- One action: **"switched racquet"** on the court session screen (and as a launcher tile action), then a tap on the new racquet. It writes (time, racquet).
- It doesn't need to be exact: Chris taps when he changes racquets, between points.

### 2.3 Matching phone times to the footage
- **Clocks:** the phone keeps network time. The cameras' clocks come from the phone through Timecode Sync (Part D), and the footage carries its start time. So phone times and video times agree to well under a second, which is plenty: switches happen between points.
- **Rule:** a switch takes effect at the **next rally start after the tap**. If the tap falls inside a rally (a late tap), the app asks once after the session: "You switched to Blade #2 during rally 14. From rally 14 or 15?"
- **Each shot gets:**
  - its racquet;
  - the string setup active on the session date (string, gauge, tension, hybrid);
  - the string age at that moment: days since restring, and hours played since restring. Hours count logged sessions before this one, plus the time in this session up to the shot.
- The string setup is **snapshotted** onto the session's racquet segments when the session is linked. A restring entered or changed later doesn't silently rewrite past sessions; editing a past restring asks whether to update the linked sessions.

### 2.4 After the session: review and correct
- The vision session's summary gets a **racquets** section: "rallies 1–13 Blade #1 · rallies 14–31 Blade #2".
- **Review** opens a list of rallies with their racquet. Chris can:
  - move a switch to another rally boundary;
  - add a switch he forgot to tap ("switched before rally 9");
  - delete a wrong one.

  Each rally row shows its first frame, so he can see the racquet in his hand.
- Changes apply at once to that session's stats and trends. No PC rerun is needed, since the racquet is the app's own data.

### 2.5 Comparing racquets, strings and string age
- **Trends** (TV-APP-06) gain a "group by" choice:
  - racquet;
  - string setup;
  - string age (bands: 0–5, 5–15, 15–30, 30+ hours since restring).
- Per group: depth, spin effect, serve speed, placement spread (the consistency ellipse), in-percentage, net clearance, with the shot count and a ± band.
- **Only Chris's shots are counted,** and only from sessions whose identity is settled (TV-PLY-07).

### 2.6 Data (phone only)
- `racquet_log(sessionRef, utcMillis, racquetId, source = tap | review | assumed)`.
- `vision_racquet_segments(visionSessionId, fromRally, racquetId, stringJobId, mainsLb, crossesLb, restringDate)`, the snapshot.
- Shots carry no racquet field in the cloud. The app joins by rally.

### 2.7 Tests
- Unit tests for:
  - a tap between rallies;
  - a late tap inside a rally;
  - a forgotten Start (overlap rule);
  - a forgotten switch added in review;
  - a restring edited after the session (snapshot kept unless confirmed).
- Screenshot tests of the racquets section and the review list, on the spoof session.

## 3. Waiting for the rest of Part F

- **Fatigue:** the title mentions it, but the requirement text was cut off.
- Anything after "performance dr…": presumably "drops as strings age", which section 2.5 covers. I'll confirm once the full text arrives.
