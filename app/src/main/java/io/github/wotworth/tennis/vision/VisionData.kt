package io.github.wotworth.tennis.vision

import org.json.JSONArray
import org.json.JSONObject

/**
 * Tennis Vision sessions (docs/VISION-REQUIREMENTS.md, TV-APP-01 to 05): what the closet PC
 * measured. The PC writes session.json, shots.json, rallies.json and trajectories.json
 * (TV-OUT-01 to 03); this file reads them. SI units throughout (m, s, m/s): the screens convert
 * to mph and feet (TV-ARCH-11, [Units]).
 */
data class VisionSession(
    val id: String,
    val startUtc: String,
    val sample: Boolean,
    val shots: List<VisionShot>,
    val rallies: List<VisionRally>,
    val trajectories: List<Trajectory>,
    val airRho: Double?,
    val wind: List<Double>,
    val sessionCD: Double?,
    val crossing: Crossing?,
    val identityQuestion: Boolean,
    val heartRate: List<HrSample> = emptyList(),
    val tempC: Double? = null,
    /** 22 Nov (item 10): the session's gusts as the PC judged them: calm, breezy, gusty or unknown. */
    val windLevel: String = "unknown",
    val synthetic: Boolean = false,
    /** What the PC did not analyse, and why (TV-ADJ-06): balls and people from other courts and the like. */
    val rejects: Rejects? = null,
) {
    /** Before "which one is you?" is answered, players are Player A and Player B; after, one is "you". */
    fun who(hitter: String, chrisLabel: String?): String = when {
        hitter == "Chris" || (chrisLabel != null && hitter == chrisLabel) -> "you"
        else -> hitter
    }
    val durationS: Double get() = (rallies.maxOfOrNull { it.stop } ?: 0.0) - (rallies.minOfOrNull { it.start } ?: 0.0)
    fun shot(rally: Int, index: Int) = shots.firstOrNull { it.rally == rally && it.index == index }
    fun trajectory(rally: Int, index: Int) = trajectories.firstOrNull { it.rally == rally && it.shot == index }
}

data class VisionShot(
    val rally: Int,
    val index: Int,
    val t: Double,
    val hitter: String,
    val type: String,
    val isServe: Boolean,
    val speedContact: Double?,
    val speedBounce: Double?,
    val launchDeg: Double?,
    val contact: List<Double>,
    val netClearance: Double?,
    val apex: Double?,
    val flightTime: Double?,
    val bounce: List<Double>?,
    val bounceSd: Double?,
    val depth: Double?,
    val call: String,
    val spinEffect: Double?,
    val spinTop: Double?,
    val spinSide: Double? = null,
    /** How far spin curved the ball sideways at the bounce, m (Chris, 17 Nov; older files: none). */
    val spinCurve: Double? = null,
    /** The curve's own uncertainty from the fit, m (one standard deviation; Chris, 21 Nov; older files: none). */
    val spinCurveSd: Double? = null,
    val rpm: Double?,
    val rpmSd: Double?,
    val spinLabel: String,
    val kickAngleDeg: Double?,
    val confidence: Double?,
)

data class VisionRally(val index: Int, val start: Double, val stop: Double, val shots: Int, val ending: String, val fastest: Double?)

/** A shot's path, sampled every [dt] seconds from [t0], with the same launch without spin. */
data class Trajectory(val rally: Int, val shot: Int, val t0: Double, val dt: Double, val xyz: List<DoubleArray>, val noSpin: List<DoubleArray>)

data class Crossing(val minDeg: Double, val thresholdDeg: Double, val low: List<String>, val text: String)

data class HrSample(val t: Double, val bpm: Int)

/** Counts by reason, largest first, and the session file with the full report (served by the Worker). */
data class Rejects(val counts: List<Pair<String, Int>>, val report: String) {
    val total: Int get() = counts.sumOf { it.second }
}

object VisionJson {
    fun session(id: String, session: String, shots: String, rallies: String, trajectories: String?, sample: Boolean, hr: String? = null): VisionSession {
        val s = JSONObject(session)
        val air = s.optJSONObject("air")
        val cr = s.optJSONObject("crossing")
        return VisionSession(
            id = id,
            startUtc = s.optString("startUtc"),
            sample = sample,
            shots = array(shots).map { shot(it) },
            rallies = array(rallies).map { rally(it) },
            trajectories = trajectories?.let { t -> array(t).map { traj(it) } } ?: emptyList(),
            airRho = air?.num("rho"),
            wind = air?.optJSONArray("wind")?.let { a -> (0 until a.length()).map { a.optDouble(it) } } ?: emptyList(),
            sessionCD = air?.num("sessionCD"),
            windLevel = air?.optString("windLevel")?.takeIf { it.isNotBlank() } ?: "unknown",
            crossing = cr?.let {
                Crossing(it.num("minDeg") ?: 0.0, it.num("thresholdDeg") ?: 20.0, strings(it.opt("low")), it.optString("text"))
            },
            identityQuestion = s.optJSONObject("identity")?.optBoolean("question") ?: false,
            heartRate = hr?.let { h -> array(h).map { HrSample(it.getDouble("t"), it.getInt("bpm")) } } ?: emptyList(),
            tempC = air?.num("tempC"),
            synthetic = s.optBoolean("synthetic"),
            rejects = s.optJSONObject("rejects")?.let { r ->
                val c = r.opt("counts")
                val list = when (c) {
                    is JSONObject -> listOf(c)
                    is JSONArray -> (0 until c.length()).mapNotNull { c.optJSONObject(it) }
                    else -> emptyList()
                }
                Rejects(list.map { it.optString("reason") to it.optInt("n") }.sortedByDescending { it.second }, r.optString("report"))
            },
        )
    }

    private fun shot(o: JSONObject) = VisionShot(
        rally = o.getInt("rally"), index = o.getInt("index"), t = o.optDouble("t"),
        hitter = o.optString("hitter", "unknown"), type = o.optString("type", "groundstroke"),
        isServe = o.optBoolean("isServe"), speedContact = o.num("speedContact"), speedBounce = o.num("speedBounce"),
        launchDeg = o.num("launchDeg"), contact = doubles(o.optJSONArray("contact")),
        netClearance = o.num("netClearance"), apex = o.num("apex"), flightTime = o.num("flightTime"),
        bounce = doubles(o.optJSONArray("bounce")).takeIf { it.size == 2 && it.all { v -> !v.isNaN() } },
        bounceSd = o.num("bounceSd"), depth = o.num("depth"), call = o.optString("call"),
        spinEffect = o.num("spinEffect"), spinTop = o.num("spinTop"), spinSide = o.num("spinSide"), spinCurve = o.num("spinCurve"), spinCurveSd = o.num("spinCurveSd"), rpm = o.num("rpm"), rpmSd = o.num("rpmSd"),
        spinLabel = o.optString("spinLabel"), kickAngleDeg = o.num("kickAngleDeg"), confidence = o.num("confidence"),
    )

    private fun rally(o: JSONObject) = VisionRally(o.getInt("index"), o.optDouble("start"), o.optDouble("stop"),
        o.optInt("shots"), o.optString("ending"), o.num("fastest"))

    private fun traj(o: JSONObject) = Trajectory(o.getInt("rally"), o.getInt("shot"), o.optDouble("t0"), o.optDouble("dt"),
        points(o.optJSONArray("xyz")), points(o.optJSONArray("noSpin")))

    /** MATLAB writes a one-row matrix as a flat array and a lone struct as an object. */
    private fun array(text: String): List<JSONObject> {
        val t = text.trim()
        if (t.startsWith("{")) return listOf(JSONObject(t))
        val a = JSONArray(t)
        return (0 until a.length()).mapNotNull { a.optJSONObject(it) }
    }

    private fun points(a: JSONArray?): List<DoubleArray> {
        if (a == null || a.length() == 0) return emptyList()
        if (a.optJSONArray(0) == null) return listOf(DoubleArray(a.length()) { a.optDouble(it) })
        return (0 until a.length()).map { i -> a.getJSONArray(i).let { r -> DoubleArray(r.length()) { r.optDouble(it) } } }
    }

    private fun doubles(a: JSONArray?): List<Double> = if (a == null) emptyList() else (0 until a.length()).map { a.optDouble(it) }

    private fun strings(v: Any?): List<String> = when (v) {
        is JSONArray -> (0 until v.length()).map { v.optString(it) }
        is String -> if (v.isBlank()) emptyList() else listOf(v)
        else -> emptyList()
    }

    private fun JSONObject.num(k: String): Double? = if (isNull(k) || !has(k)) null else optDouble(k).takeIf { !it.isNaN() }
}

/** TV-APP-06: one session's figures for the trends (the PC computes them; the app only draws). */
data class TrendPoint(val epochDay: Long, val forehandSpinEffect: Double, val forehandDepth: Double, val shots: Int, val metrics: SessionMetrics? = null)

object TrendJson {
    fun read(text: String): List<TrendPoint> {
        val a = JSONObject(text).getJSONArray("sessions")
        return (0 until a.length()).map { a.getJSONObject(it) }.map {
            TrendPoint(it.getLong("epochDay"), it.getDouble("forehandSpinEffect"), it.getDouble("forehandDepth"), it.optInt("shots"), SessionMetrics.read(it.optJSONObject("metrics")))
        }
    }
}

/**
 * A serve's spin, named as players do (Chris, 17 Nov): "kick" (topspin), "slice" (mostly
 * sideways: it curves rather than dips), or "flat". The pipeline names spin by its top/back part
 * only, so a sideways serve could read "topspin" or "slice" (backspin) by its small vertical part.
 */
fun serveSpinKind(s: VisionShot): String = when {
    s.spinLabel.startsWith("flat") -> "flat"
    s.spinSide != null && s.spinTop != null && kotlin.math.abs(s.spinSide) > kotlin.math.abs(s.spinTop) -> "slice"
    (s.spinTop ?: 0.0) >= 0 -> "kick"
    else -> "underspin"
}

/** The spin figure that fits the kind: how far a slice serve curved, else how much shorter it landed (m). */
fun spinAmount(s: VisionShot): Double? = if (s.isServe && serveSpinKind(s) == "slice") s.spinCurve?.let { kotlin.math.abs(it) } else s.spinEffect?.let { -it }
