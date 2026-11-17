package io.github.wotworth.tennis.vision

import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * Chris, 17 Nov: a session's key figures, for the summary page (against the average of his
 * earlier sessions) and the session's trends tab. His shots only. SI units (m, m/s), like the
 * session files; the screens convert.
 *   topspin    how much spin brought his forehands' and backhands' bounce shorter (mean, m;
 *              positive: shorter than the same shot without spin)
 *   speed      his forehands' and backhands' speed at contact (mean, m/s); serves left out
 *   serves     % of his serves in, their speed (mean) and spin (the commonest kind, and the mean
 *              effect on the bounce, m, positive: shorter)
 *   accuracy   % of his shots in, serves left out (in / in, out, net, too close), and how deep
 *              the ones in landed (mean, m inside the baseline)
 */
data class SessionMetrics(
    val topspinForehand: Double? = null,
    val topspinBackhand: Double? = null,
    val speedForehand: Double? = null,
    val speedBackhand: Double? = null,
    val serveInPct: Int? = null,
    val serveSpeed: Double? = null,
    val serveSpinKind: String? = null,
    val serveSpin: Double? = null,
    val inPct: Int? = null,
    val depth: Double? = null,
) {
    companion object {
        private val CALLED = setOf("in", "out", "net", "too close")

        /** [me]: the hitter label that is Chris in this session. */
        fun of(v: VisionSession, me: String): SessionMetrics {
            val mine = v.shots.filter { it.hitter == me }
            val serves = mine.filter { it.isServe }
            val rally = mine.filter { !it.isServe }
            fun topspin(type: String) = mean(rally.filter { it.type == type }.mapNotNull { it.spinEffect?.let { e -> -e } })
            fun speed(type: String) = mean(rally.filter { it.type == type }.mapNotNull { it.speedContact })
            return SessionMetrics(
                topspinForehand = topspin("forehand"),
                topspinBackhand = topspin("backhand"),
                speedForehand = speed("forehand"),
                speedBackhand = speed("backhand"),
                serveInPct = pctIn(serves),
                serveSpeed = mean(serves.mapNotNull { it.speedContact }),
                serveSpinKind = serves.map { it.spinLabel }.filter { it.isNotBlank() }.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key,
                serveSpin = mean(serves.mapNotNull { it.spinEffect?.let { e -> -e } }),
                inPct = pctIn(rally),
                depth = mean(rally.filter { it.call == "in" }.mapNotNull { it.depth }),
            )
        }

        private fun pctIn(sh: List<VisionShot>): Int? {
            val c = sh.filter { it.call in CALLED }
            return if (c.isEmpty()) null else (100.0 * c.count { it.call == "in" } / c.size).roundToInt()
        }

        private fun mean(v: List<Double>): Double? = if (v.isEmpty()) null else v.average()

        /** The average of earlier sessions' figures, each figure over the sessions that have it. */
        fun average(list: List<SessionMetrics>): SessionMetrics {
            fun d(f: (SessionMetrics) -> Double?) = mean(list.mapNotNull(f))
            fun i(f: (SessionMetrics) -> Int?) = list.mapNotNull(f).takeIf { it.isNotEmpty() }?.average()?.roundToInt()
            return SessionMetrics(d { it.topspinForehand }, d { it.topspinBackhand }, d { it.speedForehand }, d { it.speedBackhand },
                i { it.serveInPct }, d { it.serveSpeed }, null, d { it.serveSpin }, i { it.inPct }, d { it.depth })
        }

        fun read(o: JSONObject?): SessionMetrics? = o?.let {
            fun d(k: String) = if (it.has(k) && !it.isNull(k)) it.getDouble(k) else null
            fun i(k: String) = if (it.has(k) && !it.isNull(k)) it.getInt(k) else null
            SessionMetrics(d("topspinForehand"), d("topspinBackhand"), d("speedForehand"), d("speedBackhand"), i("serveInPct"),
                d("serveSpeed"), it.optString("serveSpinKind").ifBlank { null }, d("serveSpin"), i("inPct"), d("depth"))
        }
    }
}
