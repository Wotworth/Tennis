package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.NumberTile
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.HeartRate
import io.github.wotworth.tennis.vision.Trajectory
import io.github.wotworth.tennis.vision.Units
import io.github.wotworth.tennis.vision.VisionSession
import io.github.wotworth.tennis.vision.VisionShot
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

/** TV-APP-02: the session detail pivots. */
val VISION_PIVOTS = listOf("summary", "court", "shots", "rallies", "3d", "health")
private const val V_SUMMARY = 0
private const val V_COURT = 1
private const val V_SHOTS = 2
private const val V_RALLIES = 3
private const val V_3D = 4
private const val V_HEALTH = 5

private val dayFormat = DateTimeFormatter.ofPattern("EEE d MMM", Locale.US)

fun visionDay(v: VisionSession): String = runCatching {
    dayFormat.format(Instant.parse(v.startUtc.replace(Regex("\\.\\d+Z$"), "Z")).atZone(ZoneId.systemDefault())).lowercase()
}.getOrDefault("session")

/** Court constants, as in the vision pipeline's tv.court.constants (ITF). */
private object Court {
    const val HALF_LENGTH = 11.885
    const val HALF_DOUBLES = 5.485
    const val HALF_SINGLES = 4.115
    const val SERVICE = 6.40
    const val POST_Y = 6.399
    const val NET_POST = 1.07
    const val NET_CENTRE = 0.914
    val lines: List<DoubleArray> = listOf(
        doubleArrayOf(-HALF_LENGTH, -HALF_DOUBLES, HALF_LENGTH, -HALF_DOUBLES), doubleArrayOf(-HALF_LENGTH, HALF_DOUBLES, HALF_LENGTH, HALF_DOUBLES),
        doubleArrayOf(-HALF_LENGTH, -HALF_SINGLES, HALF_LENGTH, -HALF_SINGLES), doubleArrayOf(-HALF_LENGTH, HALF_SINGLES, HALF_LENGTH, HALF_SINGLES),
        doubleArrayOf(-HALF_LENGTH, -HALF_DOUBLES, -HALF_LENGTH, HALF_DOUBLES), doubleArrayOf(HALF_LENGTH, -HALF_DOUBLES, HALF_LENGTH, HALF_DOUBLES),
        doubleArrayOf(-SERVICE, -HALF_SINGLES, -SERVICE, HALF_SINGLES), doubleArrayOf(SERVICE, -HALF_SINGLES, SERVICE, HALF_SINGLES),
        doubleArrayOf(-SERVICE, 0.0, SERVICE, 0.0),
    )
}

/** TV-APP-01: one wide tile per vision session at the top of the sessions page. */
@Composable
fun VisionTiles() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    val d = io.github.wotworth.tennis.ui.appData()
    app.vision.sessions(app.prefs.visionSample).forEach { v ->
        val fastest = v.shots.mapNotNull { it.speedContact }.maxOrNull()
        val court = d.court(d.visionLabel(v.id)?.courtId)?.name
        Tile(listOfNotNull("vision", court, if (v.sample) "sample" else null).joinToString(" · "), zpx(l.tileMedium * 2 + l.tileGap), zpx(l.tileMedium * 0.75f),
            description = "vision session ${visionDay(v)}", onClick = { nav.open(Screen.Vision(v.id)) }) {
            TileLines(listOf("${visionDay(v)} · ${v.shots.size} shots",
                listOf("${v.rallies.size} rallies", "fastest ${Units.mph(fastest)}").joinToString(" · ")))
        }
        Spacer(Modifier.height(zpx(l.tileGap)))
    }
}

@Composable
fun VisionSessionScreen(id: String, initial: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val v = app.vision.session(id) ?: run { Page("vision") { TennisText("This session is not on the phone.", TennisTokens.Type.listPrimary) }; return }
    PivotScreen(
        visionDay(v) + if (v.sample) " · sample" else "", VISION_PIVOTS, initial,
        onChange = { i -> nav.stack[nav.stack.lastIndex] = Screen.Vision(id, i) },
        bar = { emptyList() },
        onMore = { nav.open(Screen.Settings) },
    ) { i, _ ->
        when (i) {
            V_SUMMARY -> VisionSummary(v)
            V_COURT -> VisionCourt(v)
            V_SHOTS -> VisionShots(v)
            V_RALLIES -> VisionRallies(v)
            V_3D -> Vision3d(v)
            V_HEALTH -> VisionHealth(v)
        }
    }
}

// ---------------------------------------------------------------------------------------------
@Composable
private fun VisionSummary(v: VisionSession) {
    val zpx = LocalZpx.current
    val app = LocalApp.current
    val o = LocalOverlays.current
    val l = TennisTokens.Layout
    val chris = v.shots.filter { it.hitter == "Chris" }
    val ground = chris.filter { it.type == "groundstroke" }
    val serves = chris.filter { it.isServe }
    val called = chris.filter { it.call in setOf("in", "out", "net", "too close") }
    val w = zpx(l.tileMedium)
    PivotColumn {
        if (v.identityQuestion && (!v.sample || app.prefs.visionSampleIdentity == null)) {
            // TV-PLY-07: asked once, when the session is opened
            Tile("which one is you?", zpx(l.tileMedium * 2 + l.tileGap), zpx(l.tileMedium * 0.6f), onClick = {
                o.menu("player A" to { app.prefs.answerVisionSampleIdentity("Player A") }, "player B" to { app.prefs.answerVisionSampleIdentity("Player B") })
            }) { TileLines(listOf("1 question", "Until you answer, this session stays out of your trends.")) }
            Spacer(Modifier.height(zpx(l.tileGap)))
        }
        Row {
            NumberTile("${chris.size}", "your shots", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile(Units.mph(serves.mapNotNull { it.speedContact }.maxOrNull()).removeSuffix(" mph"), "fastest serve, mph", w, w)
        }
        Spacer(Modifier.height(zpx(l.tileGap)))
        Row {
            NumberTile(Units.mph(median(ground.mapNotNull { it.speedContact })).removeSuffix(" mph"), "groundstroke, mph", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile(if (called.isEmpty()) "–" else "${(100.0 * called.count { it.call == "in" } / called.size).roundToInt()}%", "in", w, w)
        }
        Spacer(Modifier.height(zpx(16f)))
        SectionHeader("spin")
        val fx = median(ground.mapNotNull { it.spinEffect })
        TextRow(if (fx == null) "–" else "${Units.ft(abs(fx))} ${if (fx < 0) "shorter" else "longer"}",
            "how much spin moved your groundstrokes' bounce (median)")
        TextRow(Units.rpm(median(ground.mapNotNull { it.rpm }), median(ground.mapNotNull { it.rpmSd })), "groundstroke spin rate (±25% or more)")
        TextRow(Units.inches(median(ground.mapNotNull { it.netClearance })), "net clearance (median)")
        SectionHeader("air")
        TextRow(listOfNotNull(v.airRho?.let { "%.3f kg/m³".format(Locale.US, it) }, v.wind.takeIf { it.size >= 2 }?.let { "wind ${Units.mph(hypot(it[0], it[1]))}" }).joinToString(" · "),
            v.sessionCD?.let { "ball drag %.3f (lower: worn balls)".format(Locale.US, it) })
        val d = io.github.wotworth.tennis.ui.appData()
        d.visionLabel(v.id)?.let { lab ->
            SectionHeader("court")
            TextRow(d.court(lab.courtId)?.name ?: "a deleted court", when {
                !lab.indoor -> "outdoor"
                lab.indoorSent -> "indoor: sent to the PC, which redid the air and spin"
                else -> "indoor: goes to the PC (just the flag) once the cloud is set up"
            })
        }
        v.crossing?.let { c ->
            SectionHeader("cameras")
            TextRow(if (c.low.isEmpty()) "good angles everywhere" else "weak angle: ${c.low.joinToString("; ")}", c.text)
        }
    }
}

@Composable
private fun VisionCourt(v: VisionSession) {
    val zpx = LocalZpx.current
    val nav = LocalNav.current
    var type by remember { mutableStateOf("all") }
    var who by remember { mutableStateOf("Chris") }
    val shots = v.shots.filter { it.bounce != null && (type == "all" || it.type == type) && (who == "all" || it.hitter == who) }
    val t = TennisTokens.Vision
    PivotColumn {
        ChoiceRow(null, listOf("all" to "all", "serve" to "serves", "groundstroke" to "groundstrokes"), setOf(type), { type = it })
        ChoiceRow(null, listOf("Chris" to "you", "all" to "everyone"), setOf(who), { who = it })
        Spacer(Modifier.height(zpx(8f)))
        val lengthM = 2 * (Court.HALF_LENGTH + t.courtMarginM)
        val widthM = 2 * (Court.HALF_DOUBLES + t.courtMarginM)
        var mapping by remember { mutableStateOf<(Double, Double) -> Offset>({ _, _ -> Offset.Zero }) }
        Canvas(Modifier.fillMaxWidth().height(zpx(240f * (lengthM / widthM).toFloat() * 0.62f)).pointerInput(shots) {
            detectTapGestures { p ->
                val near = shots.minByOrNull { s -> (mapping(s.bounce!![0], s.bounce[1]) - p).getDistance() }
                if (near != null && (mapping(near.bounce!![0], near.bounce[1]) - p).getDistance() < zpx(t.spotTapRadius).toPx()) {
                    nav.open(Screen.VisionShot(v.id, near.rally, near.index))
                }
            }
        }) {
            // the court runs up the screen: court x -> screen y, court y -> screen x
            val pad = zpx(t.courtSidePadding).toPx()
            val s = minOf((size.width - 2 * pad) / widthM.toFloat(), (size.height - 2 * pad) / lengthM.toFloat())
            val cx = size.width / 2;  val cy = size.height / 2
            val map = { x: Double, y: Double -> Offset(cx + (y * s).toFloat(), cy - (x * s).toFloat()) }
            mapping = map
            drawCourtTopDown(map, s)
            shots.forEach { sh -> drawCircle(speedColour(sh.speedContact), zpx(t.spotRadius).toPx(), map(sh.bounce!![0], sh.bounce[1])) }
        }
        Spacer(Modifier.height(zpx(6f)))
        TennisText("Bounces, shaded by speed: deep green slow, yellow-green fast. Tap one for that shot.", TennisTokens.Type.listSecondary)
    }
}

private fun DrawScope.drawCourtTopDown(map: (Double, Double) -> Offset, s: Float) {
    val line = TennisTokens.Colors.primary.copy(alpha = TennisTokens.Vision.lineAlpha)
    Court.lines.forEach { l -> drawLine(line, map(l[0], l[1]), map(l[2], l[3]), strokeWidth = maxOf(1f, 0.05f * s)) }
    drawLine(TennisTokens.Colors.primary, map(0.0, -Court.POST_Y), map(0.0, Court.POST_Y), strokeWidth = maxOf(1.5f, 0.08f * s))
}

fun speedColour(ms: Double?): Color {
    val t = TennisTokens.Vision
    val f = (((ms ?: 0.0) * Units.MPH_PER_MS - t.speedLowMph) / (t.speedHighMph - t.speedLowMph)).toFloat().coerceIn(0f, 1f)
    return lerp(TennisTokens.Colors.titleGradientEnd, TennisTokens.Colors.titleGradientStart, f)
}

@Composable
private fun VisionShots(v: VisionSession) {
    val nav = LocalNav.current
    PivotColumn {
        v.shots.forEach { s ->
            TextRow("rally ${s.rally} · shot ${s.index}", shotLine(s)) { nav.open(Screen.VisionShot(v.id, s.rally, s.index)) }
        }
    }
}

fun shotLine(s: VisionShot) = listOfNotNull(
    if (s.isServe) "serve" else s.type, s.hitter.let { if (it == "Chris") "you" else it.lowercase() }, Units.mph(s.speedContact),
    s.call.takeIf { it.isNotBlank() && it != "no bounce" },
).joinToString(" · ")

@Composable
private fun VisionRallies(v: VisionSession) {
    PivotColumn {
        v.rallies.forEach { r ->
            TextRow("rally ${r.index} · ${r.shots} shots", listOf("ended ${r.ending}", "fastest ${Units.mph(r.fastest)}",
                "%.0f s".format(Locale.US, r.stop - r.start)).joinToString(" · "))
        }
    }
}

// ---------------------------------------------------------------------------------------------
/**
 * TV-APP-05: an orbitable replay of a rally on a to-scale court. Drawn natively with Compose
 * (a simple perspective camera circling the court) rather than in a WebView with three.js: no
 * JavaScript engine, no extra network permission, and the Metro look is easier to hold to.
 * Drag sideways to orbit, up and down to tilt; drag along the bar below to move through time.
 */
@Composable
private fun Vision3d(v: VisionSession) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    var rally by remember { mutableIntStateOf(v.rallies.firstOrNull()?.index ?: 1) }
    var az by remember { mutableFloatStateOf(t.view3dStartAzimuthDeg) }
    var el by remember { mutableFloatStateOf(t.view3dStartElevationDeg) }
    var time by remember { mutableFloatStateOf(1f) }
    val trajs = v.trajectories.filter { it.rally == rally }
    val t0 = trajs.minOfOrNull { it.t0 } ?: 0.0
    val t1 = trajs.maxOfOrNull { it.t0 + it.dt * (it.xyz.size - 1) } ?: 1.0
    PivotColumn {
        ChoiceRow(null, v.rallies.map { it.index to "rally ${it.index}" }, setOf(rally), { rally = it; time = 1f })
        Spacer(Modifier.height(zpx(6f)))
        Canvas(Modifier.fillMaxWidth().height(zpx(t.view3dHeight)).pointerInput(Unit) {
            detectDragGestures { _, d -> az -= d.x * 0.3f; el = (el + d.y * 0.2f).coerceIn(5f, 85f) }
        }) {
            val cam = Orbit(az.toDouble(), el.toDouble(), t.view3dDistanceM.toDouble(), size.width, size.height)
            val line = TennisTokens.Colors.primary.copy(alpha = t.lineAlpha)
            Court.lines.forEach { l -> seg(cam, line, doubleArrayOf(l[0], l[1], 0.0), doubleArrayOf(l[2], l[3], 0.0), 1.5f) }
            seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, -Court.POST_Y, Court.NET_POST), doubleArrayOf(0.0, 0.0, Court.NET_CENTRE), 2f)
            seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, 0.0, Court.NET_CENTRE), doubleArrayOf(0.0, Court.POST_Y, Court.NET_POST), 2f)
            for (y in listOf(-Court.POST_Y, Court.POST_Y)) seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, y, 0.0), doubleArrayOf(0.0, y, Court.NET_POST), 2f)
            val now = t0 + (t1 - t0) * time
            trajs.forEach { tr ->
                val n = ((now - tr.t0) / tr.dt).toInt().coerceIn(-1, tr.xyz.size - 1)
                if (n < 1) return@forEach
                val path = Path()
                for (i in 0..n) cam.screen(tr.xyz[i])?.let { if (i == 0) path.moveTo(it.x, it.y) else path.lineTo(it.x, it.y) }
                drawPath(path, TennisTokens.Colors.titleGradientStart, style = Stroke(2.2f * density))
                if (now <= tr.t0 + tr.dt * (tr.xyz.size - 1)) cam.screen(tr.xyz[n])?.let { drawCircle(TennisTokens.Colors.primary, 4f * density, it) }
            }
        }
        Spacer(Modifier.height(zpx(8f)))
        Canvas(Modifier.fillMaxWidth().height(zpx(t.scrubberHeight)).pointerInput(Unit) {
            detectDragGestures { c, _ -> time = (c.position.x / size.width).coerceIn(0f, 1f) }
        }.pointerInput(Unit) { detectTapGestures { p -> time = (p.x / size.width).coerceIn(0f, 1f) } }) {
            val y = size.height / 2
            drawLine(TennisTokens.Colors.disabled, Offset(0f, y), Offset(size.width, y), strokeWidth = 2f * density)
            drawLine(TennisTokens.Colors.primary, Offset(0f, y), Offset(size.width * time, y), strokeWidth = 2f * density)
            drawRect(TennisTokens.Colors.primary, Offset(size.width * time - 4 * density, y - 10 * density),
                androidx.compose.ui.geometry.Size(8 * density, 20 * density))
        }
        TennisText("Drag the court to turn it; drag the bar to replay.", TennisTokens.Type.listSecondary)
    }
}

private class Orbit(azDeg: Double, elDeg: Double, r: Double, val w: Float, val h: Float) {
    private val a = Math.toRadians(azDeg); private val e = Math.toRadians(elDeg)
    private val eye = doubleArrayOf(r * cos(e) * cos(a), r * cos(e) * sin(a), r * sin(e))
    private val fwd = norm(doubleArrayOf(-eye[0], -eye[1], -eye[2] + 1.0))
    private val right = norm(cross(fwd, doubleArrayOf(0.0, 0.0, 1.0)))
    private val up = cross(right, fwd)
    private val f = w * 1.25
    fun screen(p: DoubleArray): Offset? {
        val d = doubleArrayOf(p[0] - eye[0], p[1] - eye[1], p[2] - eye[2])
        val z = dot(d, fwd); if (z < 0.5) return null
        return Offset((w / 2 + f * dot(d, right) / z).toFloat(), (h / 2 - f * dot(d, up) / z).toFloat())
    }
    private fun dot(a: DoubleArray, b: DoubleArray) = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    private fun cross(a: DoubleArray, b: DoubleArray) = doubleArrayOf(a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    private fun norm(a: DoubleArray): DoubleArray { val n = Math.sqrt(dot(a, a)); return doubleArrayOf(a[0] / n, a[1] / n, a[2] / n) }
}

private fun DrawScope.seg(cam: Orbit, c: Color, a: DoubleArray, b: DoubleArray, wDp: Float) {
    val p = cam.screen(a) ?: return; val q = cam.screen(b) ?: return
    drawLine(c, p, q, strokeWidth = wDp * density)
}

// ---------------------------------------------------------------------------------------------
@Composable
private fun VisionHealth(v: VisionSession) {
    val zpx = LocalZpx.current
    val app = LocalApp.current
    val birth = io.github.wotworth.tennis.health.DetectionPrefs.load(app.prefs).birthYear
    val maxHr = HeartRate.maxHr(birth, java.time.LocalDate.now().year)
    val h = HeartRate.summary(v.heartRate, v.rallies.map { it.start to it.stop }, maxHr)
    PivotColumn {
        if (h.avg == null) {
            TennisText("No heart rate for this session's time.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Heart rate comes from Health Connect on this phone and never leaves it.", TennisTokens.Type.listSecondary)
            return@PivotColumn
        }
        Row {
            val w = zpx(TennisTokens.Layout.tileMedium)
            NumberTile("${h.avg}", "average bpm", w, w)
            Spacer(Modifier.width(zpx(TennisTokens.Layout.tileGap)))
            NumberTile("${h.max}", "highest bpm", w, w)
        }
        Spacer(Modifier.height(zpx(14f)))
        TextRow("${h.inRallies ?: "–"} bpm in rallies · ${h.between ?: "–"} between", "average while playing points, and between them")
        SectionHeader("time in zones")
        val total = h.zoneSeconds.sum().coerceAtLeast(1.0)
        listOf("50–60%", "60–70%", "70–80%", "80–90%", "90%+").forEachIndexed { i, name ->
            val f = (h.zoneSeconds[i] / total).toFloat()
            Row {
                TennisText("$name of max", TennisTokens.Type.listSecondary, Modifier.width(zpx(70f)))
                Canvas(Modifier.width(zpx(160f)).height(zpx(TennisTokens.Vision.hrBarHeight))) {
                    drawRect(TennisTokens.Colors.primary, size = androidx.compose.ui.geometry.Size(size.width * f, size.height))
                }
            }
            Spacer(Modifier.height(zpx(6f)))
        }
        if (h.gaps.isNotEmpty()) TextRow("${h.gaps.size} gap${if (h.gaps.size > 1) "s" else ""} in the heart rate", "longer than a minute; left empty, not filled in")
        if (v.sample) TextRow("sample heart rate", "made up for the sample session")
    }
}

// ---------------------------------------------------------------------------------------------
/** TV-APP-04: one shot's card: its figures and a side view of the real path against no spin. */
@Composable
fun VisionShotScreen(id: String, rally: Int, index: Int) {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    val v = app.vision.session(id)
    val s = v?.shot(rally, index)
    Page("shot $rally·$index") {
        if (v == null || s == null) { TennisText("This shot is not on the phone.", TennisTokens.Type.listPrimary); return@Page }
        TennisText(shotLine(s), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(10f)))
        v.trajectory(rally, index)?.let { SideView(it, s) }
        Spacer(Modifier.height(zpx(12f)))
        TextRow(Units.mph(s.speedContact), "speed at contact" + (s.speedBounce?.let { " · ${Units.mph(it)} at the bounce" } ?: ""))
        TextRow(s.launchDeg?.let { "%.1f°".format(Locale.US, it) } ?: "–", "launch angle")
        TextRow(Units.inches(s.netClearance), "net clearance")
        TextRow(Units.ft(s.apex), "highest point")
        s.bounce?.let { b -> TextRow("${s.call} · ${Units.ft(s.depth)} inside the baseline", "bounce ± ${Units.inches(s.bounceSd)}") }
        TextRow(s.spinEffect?.let { "${Units.ft(abs(it))} ${if (it < 0) "shorter" else "longer"}" } ?: "–", "spin's effect on the bounce, against no spin")
        TextRow(s.spinLabel.ifBlank { "–" }, Units.rpm(s.rpm, s.rpmSd))
        s.kickAngleDeg?.let { TextRow("%.0f°".format(Locale.US, it), "kick off the court") }
        TextRow(s.confidence?.let { "${(it * 100).roundToInt()}%" } ?: "–", "measurement confidence")
    }
}

@Composable
private fun SideView(tr: Trajectory, s: VisionShot) {
    val zpx = LocalZpx.current
    Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.sideViewHeight))) {
        if (tr.xyz.size < 2) return@Canvas
        val p0 = tr.xyz.first()
        val far = tr.xyz.last()
        val dir = doubleArrayOf(far[0] - p0[0], far[1] - p0[1]).let { val n = hypot(it[0], it[1]); doubleArrayOf(it[0] / n, it[1] / n) }
        fun along(p: DoubleArray) = (p[0] - p0[0]) * dir[0] + (p[1] - p0[1]) * dir[1]
        val all = tr.xyz + tr.noSpin
        val maxD = all.maxOf { along(it) }.coerceAtLeast(1.0)
        val maxZ = all.maxOf { it[2] }.coerceAtLeast(1.5)
        val pad = 4f * density
        fun map(p: DoubleArray) = Offset(pad + (along(p) / maxD * (size.width - 2 * pad)).toFloat(), size.height - pad - (p[2] / maxZ * (size.height - 2 * pad)).toFloat())
        drawLine(TennisTokens.Colors.disabled, Offset(0f, size.height - pad), Offset(size.width, size.height - pad), strokeWidth = density)
        // the net, where this flight crosses x = 0
        val dNet = -p0[0] / dir[0].let { if (abs(it) < 1e-6) 1e-6 else it }
        if (dNet in 0.0..maxD) {
            val x = pad + (dNet / maxD * (size.width - 2 * pad)).toFloat()
            drawLine(TennisTokens.Colors.secondary, Offset(x, size.height - pad), Offset(x, size.height - pad - (Court.NET_CENTRE / maxZ * (size.height - 2 * pad)).toFloat()), strokeWidth = 2f * density)
        }
        fun pathOf(ps: List<DoubleArray>) = Path().apply { ps.forEachIndexed { i, p -> map(p).let { if (i == 0) moveTo(it.x, it.y) else lineTo(it.x, it.y) } } }
        drawPath(pathOf(tr.noSpin.filter { it[2] >= 0 }), TennisTokens.Colors.secondary,
            style = Stroke(1.5f * density, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6 * density, 5 * density))))
        drawPath(pathOf(tr.xyz), speedColour(s.speedContact), style = Stroke(2.5f * density))
    }
    TennisText("solid: the real path · dashed: the same shot without spin", TennisTokens.Type.listSecondary)
}

private fun median(v: List<Double>): Double? {
    if (v.isEmpty()) return null
    val s = v.sorted(); val n = s.size
    return if (n % 2 == 1) s[n / 2] else (s[n / 2 - 1] + s[n / 2]) / 2
}
