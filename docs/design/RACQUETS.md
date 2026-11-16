# Part F: racquets, sessions and fatigue (16 Nov). Not implemented; for Chris's approval.

## 1. Answers: what the current design does

**Is every session, and every shot, tied to the racquet I used, with its string setup at the time?**
- **Logged sessions** (manual, or detected from Health Connect): yes, one racquet each.
  - The string setup is the string job that was current for that racquet on the session's date: string type, gauge, tension, hybrid, restring date (STR-05). The app derives it; it doesn't copy it.
  - Since v0.4 a session can't be split between racquets (RAC-03).
- **Vision sessions** (the cameras): **not yet.**
  - The spec asks for it: TV-HC-05 links the vision session to the overlapping logged session and its racquet, asking once if unclear; TV-MET-03 links trends to racquet, string, tension and days since restring.
  - Not built. The vision sample in the app has no racquet.
- **Shots:** not tied to a racquet. They would inherit the session's one racquet once the link exists.

**Can I compare performance across racquets, string setups and string age, e.g. whether performance drops as strings go flat?**
- Specified (TV-MET-03, TV-APP-06), not built.
- Today the app compares racquets only on logged-session measures (hours on strings, feel, heart rate), not on depth, spin effect, serve speed or placement.

**Is session data merged with Health Connect heart rate to show fatigue, e.g. placement or serve speed late in a match or after long rallies?**
- **Partly.** The vision session's **health** page (built, sample data) shows:
  - heart rate over the session, with rallies shaded;
  - average and highest;
  - in rallies against between;
  - time in zones.

  It comes from Health Connect on the phone and never leaves it (TV-HC-02 to 04).
- **No fatigue analysis:** nothing links shot stats to time in the session, to rally length, or to heart rate.

**How is the racquet recorded for a session today, and what if I forget?**
- **Selected in the app.** Logging or confirming a session asks for one racquet (RAC-05, SES-05), preselected: the racquet whose page you opened it from, else the one used last.
- A session detected from Health Connect asks the same way when you confirm it.
- **If you forget:**
  - a manual session simply gets the preselected one;
  - a detected session waits unconfirmed until you answer;
  - vision sessions have no racquet at all yet.

## 2. Requirement change

**RAC-03** (one racquet per session, no split) is **replaced**:
- a session is split into racquet segments;
- each segment's time counts toward that racquet's hours on its current strings;
- RAC-05 / SES-05 pick the **starting** racquet.

## 3. Design: mid-session racquet switches

**Principle:** which racquet you held is decided on the phone and stays there, like court names. The PC never needs it. The app joins its racquet log to the shots it receives.

### 3.1 Starting racquet
- **Court session** in the app (and a launcher tile action) has **Start**: "Starting with:" and your racquets, last used first. One tap.
- It records (phone time in UTC, racquet).
- **If you forget Start:**
  - the racquet of the logged session that overlaps in time is used;
  - else the app asks once when the vision session arrives: "Which racquet did you start with?", with the last used preselected.

### 3.2 "Switched racquet"
- A big **Switched racquet** button on the court session screen and on the launcher tile, usable in a changeover.
- Tapping it:
  1. records the tap time (UTC);
  2. shows your other racquets: one tap;
  3. offers an optional reason, one tap or skip: **strings felt flat**, **broke a string**, **other**.
- Three taps at most; works with no signal (it's all on the phone).

### 3.3 Snapping to a break between points
- **Clocks:** the phone keeps network time. The cameras get their time from the phone through Timecode Sync (Part D), and the footage carries it. Phone and video agree to well under a second.
- **Rule:** each switch snaps to the **nearest break between points**. A break is the gap between one rally's end and the next rally's start, from the video's rallies (Part A: rallies from video).
  - A tap inside a rally snaps to that rally's start or end, whichever is nearer.
  - No point is ever split across two racquets.
- **Ties, or a tap more than 2 minutes from any break:** the app asks once after the session. "You switched to Blade #2 during rally 14: before or after it?"

### 3.4 Segments, shots and string setup
- The session becomes segments: (first rally, last rally, racquet, string job).
- **Every shot and stat in a segment belongs to that racquet** and to its string job at the session date: string, gauge, tension, hybrid, restring date.
- **String age per shot:** days since restring, and hours played on those strings up to that shot (earlier sessions plus this session's time on that racquet so far).
- **Snapshot:** each segment stores its string job. A restring edited later asks before it re-points past sessions (keeps STR-05's rule, made explicit).
- **Hours** (replaces RAC-03): each segment's duration counts toward its racquet's current strings. The duration runs from the segment's first rally start to the next switch, or the session end.

### 3.5 Review and correct afterwards
- The vision session's summary gets a **racquets** row: "rallies 1–13 Blade #1 · 14–31 Blade #2 (strings felt flat)".
- **Review** lists the rallies with their racquet, each with its first frame (to see the racquet in hand). You can:
  - move a switch to another break;
  - change a segment's racquet;
  - change or add a reason;
  - **add a switch you forgot** ("switched before rally 9");
  - delete a wrong one.
- Changes apply at once; the PC doesn't rerun.

### 3.6 Broken strings
- **"Broke a string"** records a **string-break event** in that racquet's string history: (racquet, the string job, time, session, hours and sessions on those strings at the break).
- **The racquet's page:**
  - the current strings show "broken on 14 Nov after 11.3 h, 9 sessions";
  - hours stop counting on that job until you log a restring.
- **Durability:** the string history and stats show, per string type and tension, the hours and sessions to breakage. A break is the strongest end-of-life signal there is; "strings felt flat" switches are kept too, as a softer one.

### 3.7 Comparing racquets, strings and string age (flat strings)
- **Trends** (TV-APP-06) get a "group by":
  - racquet;
  - string setup;
  - string age bands (0–5, 5–15, 15–30, 30+ hours on the strings).
- **Measures:** depth, spin effect, serve speed, placement spread (consistency ellipse), in-percentage, net clearance. Each with its shot count and an uncertainty band; only your shots, from sessions with a settled identity.
- **"Do my strings go flat?":** spin effect and depth plotted against hours on the strings, per string type, with the restrings and switches marked, and the switch reasons shown.

### 3.8 Fatigue (heart rate stays on the phone)
- **Computed on the phone** from the vision shots plus Health Connect heart rate, never uploaded (TV-HC rules).
- **Views on the health page:**
  - **across the session:** serve speed, depth, placement spread and in-percentage per quarter of the session (or per 20 minutes);
  - **after long rallies:** the same measures for the next rally after one of 9 or more shots, against after short ones (rally length configurable);
  - **by heart rate:** the measures for shots hit while your heart rate was in each zone;
  - each with shot counts and an uncertainty band, and "not enough shots" below 10 in a group.
- Trends across sessions can show the late-session drop, e.g. serve speed in the last quarter minus the first.

### 3.9 Data (phone only)
- `racquet_log(sessionRef, utcMillis, racquetId, reason, source = tap | review | assumed)`.
- `vision_racquet_segments(visionSessionId, fromRally, toRally, racquetId, stringJobId, snapshot of string/gauge/tension/restring date)`.
- `string_breaks(racquetId, stringJobId, utcMillis, sessionRef, hoursOnStrings, sessionsOnStrings)`.
- Shots in the cloud carry no racquet field. The app joins by rally.

### 3.10 Tests (synthetic sessions)

| Test | Expected |
|---|---|
| Single switch, tapped in a break | Two segments, split at that break; shots and stats split accordingly; hours split |
| Multiple switches (3) | Four segments, in order; each racquet's hours and string ages right |
| Switch tapped mid-point | Snaps to the nearer end of that rally; that rally wholly in one segment |
| Forgotten switch added in review | Segments and stats update without a PC rerun |
| "Broke a string" | A string-break event with the right hours and sessions; that job stops counting hours |
| Forgotten Start | Starting racquet from the overlapping logged session, else asked once |
| Restring edited after the session | Segment snapshot kept unless confirmed |
| Fatigue views | On the spoof session: quarter and long-rally groups with the right counts |

Plus screenshot tests of the switch button flow, the racquets row, the review list and the fatigue views.

### 3.11 Placement
Phase **TV-PH-4** (app and cloud), together with TV-HC-05's session linking. The switch button and string-break events don't depend on the cameras, so they could come earlier for logged sessions if Chris wants.
