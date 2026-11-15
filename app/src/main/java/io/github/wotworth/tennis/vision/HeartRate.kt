package io.github.wotworth.tennis.vision

import kotlin.math.max
import kotlin.math.min

/**
 * TV-HC-02 and 03, on the phone only (Chris, 15 Nov: heart rate never leaves the phone): a
 * session's heart rate from Health Connect samples. Times are seconds on the session clock.
 * Gaps longer than [maxGapS] are left as gaps: never filled in. Zones are shares of the
 * maximum heart rate (220 - age), each sample counting until the next one or the gap limit.
 */
data class HrSummary(
    val avg: Int?, val max: Int?,
    val zoneSeconds: List<Double>,          // five zones: 50-60, 60-70, 70-80, 80-90, 90+ % of max
    val inRallies: Int?, val between: Int?,
    val coveredS: Double, val gaps: List<Pair<Double, Double>>,
)

object HeartRate {
    const val MAX_GAP_S = 60.0

    fun summary(s: List<HrSample>, rallies: List<Pair<Double, Double>>, maxHr: Int, maxGapS: Double = MAX_GAP_S): HrSummary {
        val p = s.sortedBy { it.t }
        if (p.isEmpty()) return HrSummary(null, null, List(5) { 0.0 }, null, null, 0.0, emptyList())
        val zones = DoubleArray(5)
        val gaps = mutableListOf<Pair<Double, Double>>()
        var covered = 0.0
        var wIn = 0.0; var sIn = 0.0; var wOut = 0.0; var sOut = 0.0; var wAll = 0.0; var sAll = 0.0
        for (i in p.indices) {
            val next = if (i + 1 < p.size) p[i + 1].t else p[i].t + 1.0
            if (next - p[i].t > maxGapS) gaps += p[i].t to next
            val w = min(next - p[i].t, maxGapS).coerceAtLeast(0.0)
            covered += w
            val f = p[i].bpm.toDouble() / maxHr
            val z = when { f < 0.5 -> -1; f < 0.6 -> 0; f < 0.7 -> 1; f < 0.8 -> 2; f < 0.9 -> 3; else -> 4 }
            if (z >= 0) zones[z] += w
            wAll += w; sAll += w * p[i].bpm
            val inRally = rallies.any { (a, b) -> p[i].t in a..b }
            if (inRally) { wIn += w; sIn += w * p[i].bpm } else { wOut += w; sOut += w * p[i].bpm }
        }
        fun avg(sum: Double, w: Double) = if (w > 0) (sum / w).toInt() else null
        return HrSummary(avg(sAll, wAll), p.maxOf { it.bpm }, zones.toList(), avg(sIn, wIn), avg(sOut, wOut), covered, gaps)
    }

    /** 220 minus age; the app already asks for the birth year (DET-11). */
    fun maxHr(birthYear: Int, year: Int) = max(120, 220 - (year - birthYear))
}
