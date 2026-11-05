# Health Connect findings (DET-01)

From Chris's report for Wed 4 Nov 2026 (v0.0.2, Android 17, all 5 permissions). A day without tennis (Chris is injured). The raw file is not committed: it is Chris's health data.

| What | Found | What it means for detection (PH-2) |
| --- | --- | --- |
| Heart rate writer | `com.fitbit.FitbitMobile` only | Read heart rate from any writer, but expect Fitbit. |
| Heart rate resolution | 24,644 readings in 939 one-minute records; readings 2–3 s apart (99% of gaps ≤ 3 s) | Minute-level windows are easy; DET-10's 5-minute rolling average has ~150 readings per window. |
| Gaps | No readings 7:55–11:12 (watch off), and short gaps in the evening; last reading 20:25 | A missing minute is a gap, not a low heart rate. A window can't bridge a gap longer than the DET-10 allowance. |
| Steps writers | Fitbit (156 one-minute records) **and** the phone's own step counter (41 records, `com.android.healthconnect.phone…`, Galaxy S25), overlapping | Summing all step records double-counts. Use Fitbit's steps for a window when it has any; else the phone's. |
| Workouts | None that day | Still unknown whether Fitbit writes ExerciseSession records. Check with a day that has a Fitbit workout. |
| Resting heart rate | 68 bpm (Fitbit, one record) | DET-11's threshold can use it. |
| Busiest minutes | Highest minute average under 120 bpm; at most 4 minutes in a row at or above 100 bpm (single readings up to 140 at 15:02, a walk) | A normal day stays well clear of a "30 minutes above ~120" rule. The threshold still needs a real tennis day to calibrate. |
| Device field | Empty on Fitbit records | Nothing to rely on there. |
