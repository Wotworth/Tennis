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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.drawText
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.MetroButton
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

/** Starting filters for the court map (the screenshot tests set them). */
object VisionDefaults {
    var courtType = "all"
    var courtColour = "speed"
}

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
    val checks = app.vision.checks(app.prefs.visionSample).size
    if (checks > 0) TextRow("ball check", "$checks frames to look at: a few taps teach the detector") { nav.open(Screen.BallCheck) }
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
    val nav = LocalNav.current
    val d = io.github.wotworth.tennis.ui.appData()
    val l = TennisTokens.Layout
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    val pending = v.identityQuestion && answer == null
    val players = v.shots.map { it.hitter }.distinct().sorted()
    val me = players.firstOrNull { v.who(it, answer) == "you" }
    val w = zpx(l.tileMedium)
    PivotColumn {
        if (v.synthetic) {
            TennisText("Synthetic data, made to preview the design: not from cameras.", TennisTokens.Type.listSecondary)
            Spacer(Modifier.height(zpx(8f)))
        }
        if (pending) {
            // TV-PLY-07: asked once, when the session is opened
            Tile("which one is you?", zpx(l.tileMedium * 2 + l.tileGap), zpx(l.tileMedium * 0.85f), onClick = { nav.open(Screen.VisionIdentity(v.id)) }) {
                TileLines(listOf("1 question", "Until you answer, stats are by player and stay out of your trends."))
            }
            Spacer(Modifier.height(zpx(l.tileGap)))
        }
        val opp = app.vision.opponents
        @Suppress("UNUSED_VARIABLE") val ov = opp.version
        if (!pending && !opp.answered(v.id)) {
            Tile("who did you play?", zpx(l.tileMedium * 2 + l.tileGap), zpx(l.tileMedium * 0.6f), onClick = { nav.open(Screen.OpponentPrompt(v.id)) }) {
                TileLines(listOf("1 tap"))
            }
            Spacer(Modifier.height(zpx(l.tileGap)))
        }
        val mine = v.shots.filter { me != null && it.hitter == me }
        val serves = (if (me != null) mine else v.shots).filter { it.isServe }
        Row {
            NumberTile("${v.shots.size}", "shots", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile("${v.rallies.size}", "rallies, ${(v.durationS / 60).roundToInt()} min", w, w)
        }
        Spacer(Modifier.height(zpx(l.tileGap)))
        Row {
            NumberTile(Units.mph(serves.mapNotNull { it.speedContact }.maxOrNull()), if (me != null) "your top serve" else "top serve", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile("${v.rallies.maxOfOrNull { it.shots } ?: 0}", "longest rally", w, w)
        }
        Spacer(Modifier.height(zpx(16f)))
        SectionHeader("players")
        val showOpp = pending || v.id in app.prefs.opponentStatsOn
        val oppName = opp.of(v.id)?.name
        players.forEach { p ->
            val label = v.who(p, answer).let { if (it != "you" && oppName != null) oppName else it }
            if (label == "you" || showOpp) TextRow(label, playerLine(v.shots.filter { it.hitter == p }))
            else TextRow(label, "their stats are off for this session")
        }
        if (!pending) io.github.wotworth.tennis.ui.components.ToggleSwitch("opponent's stats", v.id in app.prefs.opponentStatsOn) { app.prefs.showOpponentStats(v.id, it) }
        val lab = d.visionLabel(v.id)
        SectionHeader("court")
        val court = d.court(lab?.courtId)
        TextRow(court?.name ?: "no court picked", court?.let { "layout ${it.layout}: ${layoutText(it.layout)} · ${it.lensMode}" + if (it.indoor) " · indoor" else "" }
            ?: "Pick a court in the library before you play, and the session gets its name.")
        v.crossing?.let { c ->
            TextRow(if (c.low.isEmpty()) "camera angles good everywhere" else "weak camera angle: ${c.low.joinToString("; ")}",
                "the two cameras' sight lines cross at ${c.minDeg.roundToInt()}° or more (usable from ${c.thresholdDeg.roundToInt()}°)")
        }
        SectionHeader("spin" + if (me != null) "" else " · ${players.firstOrNull() ?: ""}")
        val fh = (if (me != null) mine else v.shots.filter { it.hitter == players.firstOrNull() }).filter { it.type == "forehand" || it.type == "groundstroke" }
        val fx = median(fh.mapNotNull { it.spinEffect })
        TextRow(if (fx == null) "–" else "${Units.ft(abs(fx))} ${if (fx < 0) "shorter" else "longer"}", "how much spin moved the forehands' bounce (median)")
        spinRows(if (me != null) mine else v.shots.filter { it.hitter == players.firstOrNull() }).forEach { (a, b) -> TextRow(a, b) }
        TextRow(Units.inches(median(fh.mapNotNull { it.netClearance })), "forehand net clearance (median)")
        TextRow("trends", "forehand spin and depth, session by session") { nav.open(Screen.VisionTrends) }
        SectionHeader("air")
        TextRow(listOfNotNull(v.tempC?.let { "${(it * 9 / 5 + 32).roundToInt()} °F" }, v.wind.takeIf { it.size >= 2 }?.let { "wind ${Units.mph(hypot(it[0], it[1]))}" }).joinToString(" · ").ifBlank { "–" },
            v.sessionCD?.let { "ball drag %.3f (falls as balls wear)".format(Locale.US, it) })
    }
}

/**
 * Spin by kind (Chris, 15 Nov: rpm alone does not tell topspin from slice): for each shot type,
 * one row per spin kind, with its rpm and uncertainty.
 */
fun spinRows(sh: List<VisionShot>): List<Pair<String, String>> =
    sh.filter { it.rpm != null }.groupBy { it.type to it.spinLabel }.entries
        .sortedByDescending { it.value.size }
        .map { (k, v) ->
            "${k.first} ${k.second}" to "${Units.rpm(median(v.mapNotNull { it.rpm }), median(v.mapNotNull { it.rpmSd }))} · ${v.size} shots"
        }

fun playerLine(sh: List<VisionShot>): String {
    val fhs = sh.filter { it.type == "forehand" }.mapNotNull { it.speedContact }
    val called = sh.filter { it.call in setOf("in", "out", "net", "too close") }
    return listOfNotNull("${sh.size} shots",
        sh.filter { it.isServe }.mapNotNull { it.speedContact }.maxOrNull()?.let { "serve ${Units.mph(it)}" },
        median(fhs)?.let { "forehand ${Units.mph(it)}" },
        if (called.isEmpty()) null else "${(100.0 * called.count { it.call == "in" } / called.size).roundToInt()}% in",
    ).joinToString(" · ")
}

@Composable
private fun VisionCourt(v: VisionSession) {
    val zpx = LocalZpx.current
    val nav = LocalNav.current
    val app = LocalApp.current
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    var type by remember { mutableStateOf(VisionDefaults.courtType) }
    var who by remember { mutableStateOf("all") }
    var colourBy by remember { mutableStateOf(VisionDefaults.courtColour) }
    val players = v.shots.map { it.hitter }.distinct().sorted()
    val shots = v.shots.filter { it.bounce != null && (type == "all" || it.type == type) && (who == "all" || it.hitter == who) }
    val t = TennisTokens.Vision
    PivotColumn {
        ChoiceRow(null, listOf("all" to "all", "serve" to "serves", "forehand" to "forehands", "backhand" to "backhands"), setOf(type), { type = it })
        ChoiceRow(null, listOf("speed" to "by speed", "spin" to "by spin effect"), setOf(colourBy), { colourBy = it })
        ChoiceRow(null, listOf("all" to "everyone") + players.map { it to v.who(it, answer) }, setOf(who), { who = it })
        Spacer(Modifier.height(zpx(8f)))
        val lengthM = 2 * (Court.HALF_LENGTH + t.courtMarginM)
        val widthM = 2 * (Court.HALF_DOUBLES + t.courtMarginM)
        var mapping by remember { mutableStateOf<(Double, Double) -> Offset>({ _, _ -> Offset.Zero }) }
        Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.courtMapHeight)).pointerInput(shots) {
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
            shots.forEach { sh ->
                val c = if (colourBy == "speed") speedColour(sh.speedContact) else spinColour(sh.spinEffect)
                drawCircle(c, zpx(t.spotRadius).toPx(), map(sh.bounce!![0], sh.bounce[1]))
            }
        }
        Spacer(Modifier.height(zpx(6f)))
        ScaleBar(if (colourBy == "speed") "${t.speedLowMph.roundToInt()} mph" else "no spin", if (colourBy == "speed") "${t.speedHighMph.roundToInt()} mph" else "${t.spinEffectHighFt.roundToInt()} ft shorter")
        Spacer(Modifier.height(zpx(6f)))
        TennisText("${shots.size} bounces. Tap one for that shot.", TennisTokens.Type.listSecondary)
    }
}

/** The colour scale under the court map: the title gradient, deep green to yellow-green. */
@Composable
private fun ScaleBar(low: String, high: String) {
    val zpx = LocalZpx.current
    Row {
        TennisText(low, TennisTokens.Type.listSecondary, Modifier.width(zpx(60f)))
        Canvas(Modifier.width(zpx(120f)).height(zpx(10f)).align(androidx.compose.ui.Alignment.CenterVertically)) {
            drawRect(androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(TennisTokens.Colors.titleGradientEnd, TennisTokens.Colors.titleGradientStart)))
        }
        Spacer(Modifier.width(zpx(8f)))
        TennisText(high, TennisTokens.Type.listSecondary)
    }
}

fun spinColour(effectM: Double?): Color {
    val t = TennisTokens.Vision
    val f = ((-(effectM ?: 0.0)) * Units.FT_PER_M / t.spinEffectHighFt).toFloat().coerceIn(0f, 1f)
    return lerp(TennisTokens.Colors.titleGradientEnd, TennisTokens.Colors.titleGradientStart, f)
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
    val app = LocalApp.current
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    PivotColumn {
        v.shots.forEach { s ->
            TextRow("rally ${s.rally} · shot ${s.index}", shotLine(s, v.who(s.hitter, answer))) { nav.open(Screen.VisionShot(v.id, s.rally, s.index)) }
        }
    }
}

fun shotLine(s: VisionShot, who: String = s.hitter) = listOfNotNull(
    s.type, who, Units.mph(s.speedContact), s.call.takeIf { it.isNotBlank() && it != "no bounce" },
).joinToString(" · ")

@Composable
private fun VisionRallies(v: VisionSession) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    PivotColumn {
        v.rallies.forEach { r ->
            app.vision.rallyFrame(v.id, r.index)?.let { b ->
                androidx.compose.foundation.Image(b.asImageBitmap(), "rally ${r.index}, ball path drawn", contentScale = androidx.compose.ui.layout.ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(zpx(4f)))
            }
            TextRow("rally ${r.index} · ${r.shots} shots", listOf("ended ${r.ending}", "fastest ${Units.mph(r.fastest)}",
                "%.0f s".format(Locale.US, r.stop - r.start)).joinToString(" · "),
                onLongClick = { nav.open(Screen.MissedShot(v.id, r.index)) })
            io.github.wotworth.tennis.ui.components.SmallAction("missed a shot?") { nav.open(Screen.MissedShot(v.id, r.index)) }
            Spacer(Modifier.height(zpx(6f)))
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
        Row {
            io.github.wotworth.tennis.ui.components.SmallAction("previous", rally > (v.rallies.firstOrNull()?.index ?: 1)) { rally -= 1; time = 1f }
            Spacer(Modifier.width(zpx(14f)))
            TennisText("rally $rally of ${v.rallies.size}", TennisTokens.Type.body)
            Spacer(Modifier.width(zpx(14f)))
            io.github.wotworth.tennis.ui.components.SmallAction("next", rally < (v.rallies.lastOrNull()?.index ?: 1)) { rally += 1; time = 1f }
        }
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
        HrChart(v)
        Spacer(Modifier.height(zpx(4f)))
        TennisText("heart rate over the session; rallies shaded; gaps over a minute left empty", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(12f)))
        Row {
            val w = zpx(TennisTokens.Layout.tileMedium)
            NumberTile("${h.avg}", "average bpm", w, w)
            Spacer(Modifier.width(zpx(TennisTokens.Layout.tileGap)))
            NumberTile("${h.max}", "highest bpm", w, w)
        }
        Spacer(Modifier.height(zpx(14f)))
        TextRow("${h.inRallies ?: "–"} bpm in rallies · ${h.between ?: "–"} between", "average while playing points, and between them")
        SectionHeader("time in zones, % of max heart rate")
        val total = h.zoneSeconds.sum().coerceAtLeast(1.0)
        listOf("50–60%", "60–70%", "70–80%", "80–90%", "90%+").forEachIndexed { i, name ->
            val f = (h.zoneSeconds[i] / total).toFloat()
            Row {
                TennisText(name, TennisTokens.Type.listSecondary, Modifier.width(zpx(52f)))
                Canvas(Modifier.width(zpx(140f)).height(zpx(TennisTokens.Vision.hrBarHeight))) {
                    drawRect(TennisTokens.Colors.primary, size = androidx.compose.ui.geometry.Size(size.width * f, size.height))
                }
                Spacer(Modifier.width(zpx(6f)))
                TennisText("${(h.zoneSeconds[i] / 60).roundToInt()} min", TennisTokens.Type.listSecondary)
            }
            Spacer(Modifier.height(zpx(6f)))
        }
        if (h.gaps.isNotEmpty()) TextRow("${h.gaps.size} gap${if (h.gaps.size > 1) "s" else ""} in the heart rate", "longer than a minute; left empty, not filled in")
        if (v.sample) TextRow("sample heart rate", "made up for the sample session, Fitbit-style")
    }
}

/** TV-HC-02, 03: heart rate over the session, the rallies shaded in tile green, gaps left open. */
@Composable
private fun HrChart(v: VisionSession) {
    val zpx = LocalZpx.current
    val hr = v.heartRate.sortedBy { it.t }
    val end = maxOf(v.rallies.maxOfOrNull { it.stop } ?: 0.0, hr.lastOrNull()?.t ?: 0.0)
    Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.hrChartHeight))) {
        val left = zpx(24f).toPx(); val bottom = size.height - zpx(14f).toPx(); val top = zpx(4f).toPx()
        val lo = 80.0; val hi = 190.0
        fun x(t: Double) = left + (t / end * (size.width - left)).toFloat()
        fun y(b: Double) = bottom - ((b - lo) / (hi - lo)).toFloat() * (bottom - top)
        v.rallies.forEach { r -> drawRect(TennisTokens.Colors.tile, Offset(x(r.start), top), androidx.compose.ui.geometry.Size(x(r.stop) - x(r.start), bottom - top)) }
        for (b in listOf(100.0, 140.0, 180.0)) drawLine(TennisTokens.Colors.disabled, Offset(left, y(b)), Offset(size.width, y(b)), strokeWidth = density * 0.6f)
        val path = Path()
        hr.forEachIndexed { i, p ->
            val gap = i == 0 || p.t - hr[i - 1].t > HeartRate.MAX_GAP_S
            if (gap) path.moveTo(x(p.t), y(p.bpm.toDouble())) else path.lineTo(x(p.t), y(p.bpm.toDouble()))
        }
        drawPath(path, TennisTokens.Colors.primary, style = Stroke(1.6f * density))
    }
    Row(Modifier.fillMaxWidth()) {
        TennisText("180 · 140 · 100 bpm", TennisTokens.Type.listSecondary, Modifier.weight(1f))
        TennisText("${(end / 60).roundToInt()} min", TennisTokens.Type.listSecondary)
    }
}

// ---------------------------------------------------------------------------------------------
/** TV-PLY-07: "which one is you?" with one picture per player; one tap relabels every shot. */
@Composable
fun VisionIdentityScreen(id: String) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val v = app.vision.session(id) ?: return
    val players = v.shots.map { it.hitter }.distinct().sorted()
    Page("which one is you?") {
        TennisText("The cameras could not tell who was who in this session. Tap yourself; every shot is relabelled, and the session joins your trends.", TennisTokens.Type.body)
        Spacer(Modifier.height(zpx(14f)))
        Row {
            players.forEachIndexed { i, p ->
                if (i > 0) Spacer(Modifier.width(zpx(TennisTokens.Layout.tileGap)))
                val sh = v.shots.filter { it.hitter == p }
                Tile(p.lowercase(), zpx(TennisTokens.Layout.tileMedium), zpx(TennisTokens.Layout.tileMedium * 1.6f), description = "$p is me",
                    onClick = { app.prefs.answerVisionSampleIdentity(p); nav.back() },
                    background = {
                        app.vision.playerThumb(v.id, p)?.let { b ->
                            androidx.compose.foundation.Image(b.asImageBitmap(), null, contentScale = androidx.compose.ui.layout.ContentScale.Crop, modifier = Modifier.matchParentSize())
                        }
                    }) {}
                if (i == players.lastIndex) Unit
            }
        }
        Spacer(Modifier.height(zpx(12f)))
        players.forEach { p -> TextRow(p.lowercase(), playerLine(v.shots.filter { it.hitter == p })) }
        Spacer(Modifier.height(zpx(8f)))
        TextRow("not now", "ask again next time") { nav.back() }
    }
}

// ---------------------------------------------------------------------------------------------
/**
 * TV-APP-06: trends for the forehand: spin effect and depth by session, with the restrings of
 * the racquet in use as markers (tension written by each). Sessions waiting for "which one is
 * you?" stay out. Shown on the stats pivot.
 */
@Composable
fun VisionTrendsScreen() {
    Page("trends") { VisionTrends() }
}

@Composable
fun VisionTrends() {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    val d = io.github.wotworth.tennis.ui.appData()
    val pts = app.vision.trends(app.prefs.visionSample)
    if (pts.size < 2) return
    val racquet = d.racquet(app.prefs.selectedRacquet ?: -1) ?: d.active.firstOrNull()
    val jobs = d.jobs.filter { it.racquetId == racquet?.id }
    SectionHeader("vision · forehand" + if (racquet != null) " · ${racquet.name}" else "")
    TennisText("Synthetic trend for the preview.", TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(zpx(6f)))
    TrendChart("spin effect, ft shorter", pts.map { it.epochDay to -it.forehandSpinEffect * Units.FT_PER_M }, jobs)
    Spacer(Modifier.height(zpx(10f)))
    TrendChart("depth, ft inside the baseline", pts.map { it.epochDay to it.forehandDepth * Units.FT_PER_M }, jobs)
}

@Composable
private fun TrendChart(title: String, pts: List<Pair<Long, Double>>, jobs: List<io.github.wotworth.tennis.data.StringJob>) {
    val zpx = LocalZpx.current
    val measurer = androidx.compose.ui.text.rememberTextMeasurer()
    val small = io.github.wotworth.tennis.ui.theme.textStyleFor(TennisTokens.Type.listSecondary)
    TennisText(title, TennisTokens.Type.body)
    val d0 = minOf(pts.minOf { it.first }, jobs.minOfOrNull { it.date } ?: Long.MAX_VALUE) - 2
    val d1 = pts.maxOf { it.first } + 2
    val lo = pts.minOf { it.second } * 0.85; val hi = pts.maxOf { it.second } * 1.1
    Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.trendHeight))) {
        val left = zpx(26f).toPx(); val bottom = size.height - zpx(14f).toPx(); val top = zpx(14f).toPx()
        fun x(day: Long) = left + ((day - d0).toFloat() / (d1 - d0)) * (size.width - left)
        fun y(v: Double) = bottom - ((v - lo) / (hi - lo)).toFloat() * (bottom - top)
        jobs.filter { it.date in d0..d1 }.forEach { j ->
            val xx = x(j.date)
            drawLine(TennisTokens.Colors.titleGradientStart, Offset(xx, top), Offset(xx, bottom), strokeWidth = 1.5f * density,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * density, 3 * density)))
            val label = io.github.wotworth.tennis.domain.Strings.tensionText(j) + " lb"
            drawText(measurer, label, Offset(xx + 3 * density, 0f), small.copy(color = TennisTokens.Colors.titleGradientStart))
        }
        drawLine(TennisTokens.Colors.disabled, Offset(left, bottom), Offset(size.width, bottom), strokeWidth = density)
        val path = Path()
        pts.forEachIndexed { i, (day, v) -> if (i == 0) path.moveTo(x(day), y(v)) else path.lineTo(x(day), y(v)) }
        drawPath(path, TennisTokens.Colors.primary, style = Stroke(2f * density))
        pts.forEach { (day, v) -> drawCircle(TennisTokens.Colors.primary, 3f * density, Offset(x(day), y(v))) }
        drawText(measurer, "%.1f".format(Locale.US, hi), Offset(0f, top - 8 * density), small)
        drawText(measurer, "%.1f".format(Locale.US, lo), Offset(0f, bottom - 10 * density), small)
    }
    TennisText("dashed: restrings, with the tension", TennisTokens.Type.listSecondary)
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
        TennisText(shotLine(s, v.who(s.hitter, if (v.sample) app.prefs.visionSampleIdentity else null)), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(10f)))
        v.trajectory(rally, index)?.let { SideView(it, s) }
        Spacer(Modifier.height(zpx(12f)))
        TextRow(Units.mph(s.speedContact), "speed at contact" + (s.speedBounce?.let { " · ${Units.mph(it)} at the bounce" } ?: ""))
        TextRow(s.launchDeg?.let { "%.1f°".format(Locale.US, it) } ?: "–", "launch angle")
        TextRow(Units.inches(s.netClearance), "net clearance")
        TextRow(Units.ft(s.apex), "highest point")
        s.bounce?.let { b -> TextRow("${s.call} · ${Units.ft(s.depth)} inside the baseline", "bounce ± ${Units.inches(s.bounceSd)}") }
        TextRow(s.spinEffect?.let { "${Units.ft(abs(it))} ${if (it < 0) "shorter" else "longer"}" } ?: "–", "spin's effect on the bounce, against no spin")
        TextRow(s.spinLabel.ifBlank { "–" } + (s.rpm?.let { " · ${Units.rpm(it, s.rpmSd)}" } ?: ""), spinSplit(s))
        s.kickAngleDeg?.let { TextRow("%.0f°".format(Locale.US, it), "kick off the court") }
        TextRow(s.confidence?.let { "${(it * 100).roundToInt()}%" } ?: "–", "measurement confidence")
        Spacer(Modifier.height(zpx(10f)))
        val o = LocalOverlays.current
        MetroButton("this looks wrong") {
            o.menu(*io.github.wotworth.tennis.vision.LOOKS_WRONG_REASONS.map { reason ->
                reason to { app.vision.flag(id, io.github.wotworth.tennis.vision.Feedback.looksWrong(rally, index, reason)) }
            }.toTypedArray())
        }
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
    TennisText("solid: the real path · dashed: the same shot without spin" +
        (s.spinEffect?.let { " · spin brought it down ${Units.ft(abs(it))}" } ?: ""), TennisTokens.Type.listSecondary)
}

/** The spin's two parts: topspin (+) or slice (-) across the flight, and sidespin. */
fun spinSplit(s: VisionShot): String {
    val top = s.spinTop ?: return "no spin measured"
    val side = s.spinSide ?: 0.0
    val total = kotlin.math.abs(top) + kotlin.math.abs(side)
    if (total < 1e-6) return "no spin measured"
    val tPct = (100 * kotlin.math.abs(top) / total).roundToInt()
    return "${if (top >= 0) "topspin" else "slice"} $tPct% · sidespin ${100 - tPct}%"
}

private fun median(v: List<Double>): Double? {
    if (v.isEmpty()) return null
    val s = v.sorted(); val n = s.size
    return if (n % 2 == 1) s[n / 2] else (s[n / 2 - 1] + s[n / 2]) / 2
}
