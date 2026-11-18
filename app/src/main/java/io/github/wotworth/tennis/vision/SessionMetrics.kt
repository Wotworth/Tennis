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
 *   serves     first and second serves apart (Chris, 17 Nov; [secondServes]): % in, speed (mean)
 *              and spin: the commonest kind (kick, slice or flat, [serveSpinKind]) and, for those
 *              serves, how much shorter they landed (kick, flat) or how far they curved (slice), m
 *   accuracy   % of his shots in, serves left out (in / in, out, net, too close), and how far
 *              short of the baseline the ones in landed (mean, m; smaller is deeper)
 */
data class SessionMetrics(
    val topspinForehand: Double? = null,
    val topspinBackhand: Double? = null,
    val speedForehand: Double? = null,
    val speedBackhand: Double? = null,
    val serve1InPct: Int? = null,
    val serve1Speed: Double? = null,
    val serve1SpinKind: String? = null,
    val serve1Spin: Double? = null,
    val serve2InPct: Int? = null,
    val serve2Speed: Double? = null,
    val serve2SpinKind: String? = null,
    val serve2Spin: Double? = null,
    val inPct: Int? = null,
    val depth: Double? = null,
) {
    companion object {
        private val CALLED = setOf("in", "out", "net", "too close")

        /** [me]: the hitter label that is Chris in this session. */
        fun of(v: VisionSession, me: String): SessionMetrics {
            val mine = v.shots.filter { it.hitter == me }
            val second = secondServes(v)
            val serves = mine.filter { it.isServe }
            val s1 = serves.filter { it !in second };  val s2 = serves.filter { it in second }
            val rally = mine.filter { !it.isServe }
            fun topspin(type: String) = mean(rally.filter { it.type == type }.mapNotNull { it.spinEffect?.let { e -> -e } })
            fun speed(type: String) = mean(rally.filter { it.type == type }.mapNotNull { it.speedContact })
            fun kind(sv: List<VisionShot>) = sv.map { serveSpinKind(it) }.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key
            // the serves of the commonest kind: how much shorter (kick, flat) or how far sideways (slice)
            fun spinOf(sv: List<VisionShot>) = kind(sv)?.let { k -> mean(sv.filter { serveSpinKind(it) == k }.mapNotNull { spinAmount(it) }) }
            return SessionMetrics(
                topspinForehand = topspin("forehand"),
                topspinBackhand = topspin("backhand"),
                speedForehand = speed("forehand"),
                speedBackhand = speed("backhand"),
                serve1InPct = pctIn(s1), serve1Speed = mean(s1.mapNotNull { it.speedContact }), serve1SpinKind = kind(s1),
                serve1Spin = spinOf(s1),
                serve2InPct = pctIn(s2), serve2Speed = mean(s2.mapNotNull { it.speedContact }), serve2SpinKind = kind(s2),
                serve2Spin = spinOf(s2),
                inPct = pctIn(rally),
                depth = mean(rally.filter { it.call == "in" }.mapNotNull { it.depth }),
            )
        }

        /**
         * Second serves (Chris, 17 Nov). The PC splits points where the ball stops, so a faulted
         * first serve is a rally of its own: one shot, a serve, out or in the net. The same
         * player's next serve, in the next rally, is his second serve (unless that fault was
         * itself a second serve: then the next serve starts a new point).
         */
        fun secondServes(v: VisionSession): Set<VisionShot> {
            val out = mutableSetOf<VisionShot>()
            var faulted: String? = null          // the server whose first serve just faulted
            v.rallies.sortedBy { it.start }.forEach { r ->
                val sh = v.shots.filter { it.rally == r.index }.sortedBy { it.index }
                val serve = sh.firstOrNull()?.takeIf { it.isServe } ?: run { faulted = null; return@forEach }
                val isSecond = faulted == serve.hitter
                if (isSecond) out += serve
                val fault = sh.size == 1 && serve.call in setOf("out", "net")
                faulted = if (fault && !isSecond) serve.hitter else null
            }
            return out
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
                i { it.serve1InPct }, d { it.serve1Speed }, null, d { it.serve1Spin }, i { it.serve2InPct }, d { it.serve2Speed }, null, d { it.serve2Spin },
                i { it.inPct }, d { it.depth })
        }

        fun read(o: JSONObject?): SessionMetrics? = o?.let {
            fun d(k: String) = if (it.has(k) && !it.isNull(k)) it.getDouble(k) else null
            fun i(k: String) = if (it.has(k) && !it.isNull(k)) it.getInt(k) else null
            SessionMetrics(d("topspinForehand"), d("topspinBackhand"), d("speedForehand"), d("speedBackhand"),
                i("serve1InPct"), d("serve1Speed"), it.optString("serve1SpinKind").ifBlank { null }, d("serve1Spin"),
                i("serve2InPct"), d("serve2Speed"), it.optString("serve2SpinKind").ifBlank { null }, d("serve2Spin"), i("inPct"), d("depth"))
        }
    }
}
