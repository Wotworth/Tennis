package io.github.wotworth.tennis.domain

import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.health.DayData
import io.github.wotworth.tennis.health.StepsRecord
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** DET-10, DET-11: every tunable value, changed in the hidden debug screen without a new build. */
data class DetectionSettings(
    val minMinutes: Int = 30,
    val rollingMinutes: Int = 5,
    val maxGapMinutes: Int = 5,
    /** Threshold = resting + this share of heart-rate reserve. */
    val reserveShare: Double = 0.5,
    val birthYear: Int = 1980,
    /** Used when Health Connect has no resting heart rate (DET-11). */
    val restingFallback: Int = 65,
    /** Q8: tennis only by default; "also racquet sports" adds squash, badminton, racquetball, table tennis, padel/other. */
    val otherRacquetSports: Boolean = false,
    val lookbackHours: Int = 48,
    val checkEveryMinutes: Int = 60,
    val expiryDays: Int = 7,
    val enabled: Boolean = true,
    /** DET-14 (v0.4): once enough sessions with heart rate are logged, the threshold comes from them. */
    val learn: Boolean = true,
    /** Threshold = this share of the median average heart rate of the logged sessions. */
    val learnShare: Double = 0.88,
    val learnMinSessions: Int = 3,
    val learnMaxSessions: Int = 10,
)

/** A possible session: its window, source and the numbers attached to it (DET-12). */
data class Candidate(
    val startMillis: Long,
    val endMillis: Long,
    val source: String,
    val avgHr: Int?,
    val maxHr: Int?,
    val steps: Long?,
    /** Debug only: the highest rolling average in the window. */
    val peakRolling: Int? = null,
) {
    val minutes get() = ((endMillis - startMillis) / 60_000).toInt()
}

/** A logged session's span, for DET-13. Manual sessions have only a date. */
data class Busy(val date: Long, val startMillis: Long?, val endMillis: Long?)

object Detection {

    const val MINUTE = 60_000L

    /** Exercise types counted as tennis (Health Connect's numbers: tennis 76; squash 64, badminton 5, racquetball 52, table tennis 72; other 0 is not counted). */
    fun workoutTypes(s: DetectionSettings): Set<Int> = if (s.otherRacquetSports) setOf(76, 64, 5, 52, 72) else setOf(76)

    fun maxHr(s: DetectionSettings, year: Int) = 220 - (year - s.birthYear)

    /** DET-11: resting + share × (max − resting). */
    fun threshold(s: DetectionSettings, resting: Int, year: Int): Int {
        val mx = maxHr(s, year)
        return (resting + s.reserveShare * (mx - resting)).roundToInt()
    }

    /**
     * DET-14 (v0.4): the threshold from Chris's own sessions: [DetectionSettings.learnShare] of the
     * median average heart rate of his latest sessions with heart-rate data (newest first in
     * [sessionAverages]); never under resting + 15. Null with too few sessions (then [threshold]).
     */
    fun learnedThreshold(sessionAverages: List<Int>, s: DetectionSettings, resting: Int): Int? {
        if (!s.learn) return null
        val recent = sessionAverages.take(s.learnMaxSessions)
        if (recent.size < s.learnMinSessions) return null
        val sorted = recent.sorted()
        val median = if (sorted.size % 2 == 1) sorted[sorted.size / 2].toDouble() else (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2.0
        return maxOf((median * s.learnShare).roundToInt(), resting + 15)
    }

    /** The threshold detection uses: learned when there are enough sessions, else from age. */
    fun thresholdFor(s: DetectionSettings, resting: Int, year: Int, sessionAverages: List<Int>): Int =
        learnedThreshold(sessionAverages, s, resting) ?: threshold(s, resting, year)

    /**
     * DET-14: for a session logged by hand (a date and a length, no times): the stretch of that
     * length with the highest average heart rate, where at least [coverage] of its minutes have
     * readings. Returns its first minute (epoch minute) and that average.
     */
    fun bestWindow(minutes: Map<Long, Double>, length: Int, coverage: Double = 0.7): Pair<Long, Double>? {
        if (minutes.isEmpty() || length <= 0) return null
        val first = minutes.keys.min(); val last = minutes.keys.max()
        // Ranked by the sum of the minute averages, so a window doesn't gain by sliding over
        // minutes without readings; the average returned is over the minutes with readings.
        var best: Triple<Long, Double, Double>? = null
        var start = first
        while (start + length - 1 <= last) {
            val vals = (start until start + length).mapNotNull { minutes[it] }
            if (vals.size >= length * coverage) {
                val sum = vals.sum()
                if (best == null || sum > best.third) best = Triple(start, vals.average(), sum)
            }
            start++
        }
        return best?.let { it.first to it.second }
    }

    /** The newest resting heart rate in the data, else the fallback. */
    fun resting(d: DayData, s: DetectionSettings): Int = d.restingHeartRate.maxByOrNull { it.time }?.bpm?.toInt() ?: s.restingFallback

    /** Average heart rate per minute, only for minutes with readings (keyed by epoch minute). */
    fun perMinute(d: DayData): Map<Long, Double> =
        d.heartRate.flatMap { it.samples }.groupBy { it.time.toEpochMilli() / MINUTE }.mapValues { (_, v) -> v.map { it.bpm }.average() }

    /**
     * The rolling average for each minute with data: the mean of the minute averages within
     * [rollingMinutes] centred on it. Missing minutes are left out, never counted as low.
     */
    fun rolling(minutes: Map<Long, Double>, rollingMinutes: Int): Map<Long, Double> {
        val half = rollingMinutes / 2
        return minutes.keys.associateWith { m ->
            val vals = (m - half..m - half + rollingMinutes - 1).mapNotNull { minutes[it] }
            vals.average()
        }
    }

    /**
     * DET-10 step 2: stretches of at least [DetectionSettings.minMinutes] where the rolling
     * average stays at or above the threshold, bridging up to [DetectionSettings.maxGapMinutes]
     * below it or without data. Clipped to the first and last minute above.
     */
    fun heartRateWindows(d: DayData, s: DetectionSettings, threshold: Int): List<Pair<Long, Long>> {
        val roll = rolling(perMinute(d), s.rollingMinutes)
        val hot = roll.filter { it.value >= threshold }.keys.sorted()
        val out = ArrayList<Pair<Long, Long>>()
        var start: Long? = null; var last = 0L
        for (m in hot) {
            if (start == null) { start = m; last = m; continue }
            if (m - last - 1 <= s.maxGapMinutes) last = m else { out += start to last; start = m; last = m }
        }
        if (start != null) out += start to last
        return out.filter { (a, b) -> b - a + 1 >= s.minMinutes }.map { (a, b) -> a * MINUTE to (b + 1) * MINUTE }
    }

    /** True for the phone's own step counter (its package starts with this; Chris's report, 4 Nov). */
    fun isPhone(r: StepsRecord) = r.origin.packageName.startsWith("com.android.healthconnect.phone") || r.origin.device?.contains("phone") == true

    /**
     * DET-12: steps in a window. Fitbit and the phone both count the same steps, so only the
     * watch's records are used when it has any in the window; else the phone's. A record partly
     * inside counts in proportion.
     */
    fun steps(d: DayData, start: Long, end: Long): Long? {
        fun inside(r: StepsRecord): Double {
            val a = r.start.toEpochMilli(); val b = r.end.toEpochMilli()
            val o = min(b, end) - max(a, start)
            if (o <= 0) return 0.0
            return if (b <= a) r.count.toDouble() else r.count * o.toDouble() / (b - a)
        }
        val inWindow = d.steps.filter { inside(it) > 0 }
        if (inWindow.isEmpty()) return null
        val watch = inWindow.filter { !isPhone(it) }
        return (if (watch.isNotEmpty()) watch else inWindow).sumOf { inside(it) }.roundToInt().toLong()
    }

    fun heartStats(d: DayData, start: Long, end: Long): Pair<Int?, Int?> {
        val v = d.heartRate.flatMap { it.samples }.filter { it.time.toEpochMilli() in start until end }.map { it.bpm }
        return if (v.isEmpty()) null to null else v.average().roundToInt() to v.max().toInt()
    }

    /**
     * DET-10: workouts first, then heart-rate windows that don't overlap one. Each with DET-12's
     * numbers. Nothing here knows about sessions or proposals; see [filter] and [merge].
     */
    fun detect(d: DayData, s: DetectionSettings, year: Int, threshold: Int? = null): List<Candidate> {
        val types = workoutTypes(s)
        val workouts = d.exercise.filter { it.type in types }.map { e ->
            val a = e.start.toEpochMilli(); val b = e.end.toEpochMilli()
            val (avg, mx) = heartStats(d, a, b)
            Candidate(a, b, "workout", avg, mx, steps(d, a, b))
        }.filter { it.minutes >= s.minMinutes / 2 }
        val th = threshold ?: threshold(s, resting(d, s), year)
        val roll = rolling(perMinute(d), s.rollingMinutes)
        val hr = heartRateWindows(d, s, th).filter { (a, b) -> workouts.none { overlaps(a, b, it.startMillis, it.endMillis) } }.map { (a, b) ->
            val (avg, mx) = heartStats(d, a, b)
            val peak = roll.filterKeys { it * MINUTE in a until b }.values.maxOrNull()?.roundToInt()
            Candidate(a, b, "heart_rate", avg, mx, steps(d, a, b), peak)
        }
        return (workouts + hr).sortedBy { it.startMillis }
    }

    fun overlaps(a1: Long, b1: Long, a2: Long, b2: Long) = a1 < b2 && a2 < b1

    /**
     * DET-13: drop candidates that overlap a logged session. A session logged by hand has no
     * times, so it covers its whole day (DECISIONS 2026-11-05).
     */
    fun filter(c: List<Candidate>, busy: List<Busy>, dayOf: (Long) -> Long): List<Candidate> = c.filter { cand ->
        busy.none { b ->
            if (b.startMillis != null && b.endMillis != null) overlaps(cand.startMillis, cand.endMillis, b.startMillis, b.endMillis)
            else b.date == dayOf(cand.startMillis)
        }
    }

    /** What to do with the proposals table. */
    data class Merge(val insert: List<Proposal>, val update: List<Proposal>, val expire: List<Long>)

    /**
     * DET-13, DET-20, DET-31: a candidate overlapping an answered proposal is never proposed
     * again; one overlapping a waiting proposal updates it (Fitbit syncs a session in pieces);
     * otherwise it is new. Waiting proposals older than [DetectionSettings.expiryDays] expire.
     */
    fun merge(cands: List<Candidate>, existing: List<Proposal>, s: DetectionSettings, now: Long): Merge {
        val insert = ArrayList<Proposal>(); val update = ArrayList<Proposal>()
        for (c in cands) {
            val over = existing.filter { overlaps(c.startMillis, c.endMillis, it.startMillis, it.endMillis) }
            if (over.any { it.state != "waiting" }) continue
            val w = over.firstOrNull()
            if (w != null) {
                val u = w.copy(startMillis = min(w.startMillis, c.startMillis), endMillis = max(w.endMillis, c.endMillis),
                    source = if (c.source == "workout") "workout" else w.source, avgHr = c.avgHr ?: w.avgHr, maxHr = c.maxHr ?: w.maxHr, steps = c.steps ?: w.steps)
                if (u != w) update += u
            } else if (insert.none { overlaps(c.startMillis, c.endMillis, it.startMillis, it.endMillis) }) {
                insert += Proposal(startMillis = c.startMillis, endMillis = c.endMillis, source = c.source, avgHr = c.avgHr, maxHr = c.maxHr, steps = c.steps, createdMillis = now)
            }
        }
        val expire = existing.filter { it.state == "waiting" && now - it.endMillis > s.expiryDays * 86_400_000L }.map { it.id }
        return Merge(insert, update, expire)
    }

    /** Debug screen: the longest stretch at or above the threshold, even if too short (minutes, start). */
    fun longestHot(d: DayData, s: DetectionSettings, threshold: Int): Pair<Int, Long>? {
        val w = heartRateWindows(d, s.copy(minMinutes = 1), threshold).maxByOrNull { it.second - it.first } ?: return null
        return ((w.second - w.first) / MINUTE).toInt() to w.first
    }
}
