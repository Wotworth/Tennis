package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import io.github.wotworth.tennis.R
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
/** Chris, 17 Nov: shots and rallies fold into 3D (each rally opens its replay, its shots and heart rate). */
val VISION_PIVOTS = listOf("summary", "court", "3D", "health", "trends")
private const val V_SUMMARY = 0
private const val V_COURT = 1
const val V_3D = 2
private const val V_HEALTH = 3
private const val V_TRENDS = 4

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
internal object Court {
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
    FootageTestTiles()
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
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    val filter = remember(id, answer) { VisionFilter(firstPlayer(v, answer)) }
    PivotScreen(
        visionDay(v) + if (v.sample) " · sample" else "", VISION_PIVOTS, initial,
        onChange = { i -> nav.stack[nav.stack.lastIndex] = Screen.Vision(id, i) },
        bar = { emptyList() },
        onMore = { nav.open(Screen.Settings) },
    ) { i, _ ->
        when (i) {
            V_SUMMARY -> VisionSummary(v)
            V_COURT -> VisionCourt(v, filter)
            V_3D -> VisionRallyList(v)
            V_HEALTH -> VisionHealth(v)
            V_TRENDS -> SessionTrends(v, v.shots.map { it.hitter }.distinct().firstOrNull { v.who(it, answer) == "you" })
        }
    }
}

/** The session at a glance: shots, rallies, minutes, longest rally, as small dark tiles. */
@Composable
private fun SessionTiles(v: VisionSession) {
    val zpx = LocalZpx.current
    SectionHeader("session")
    Row(Modifier.fillMaxWidth()) {
        listOf("${v.shots.size}" to "shots", "${v.rallies.size}" to "rallies", "${(v.durationS / 60).roundToInt()}" to "min",
            "${v.rallies.maxOfOrNull { it.shots } ?: 0}" to "longest rally").forEachIndexed { k, (n, label) ->
            if (k > 0) Spacer(Modifier.width(zpx(TennisTokens.Layout.tileGap)))
            Column(Modifier.weight(1f).background(TennisTokens.Colors.segmentOff).padding(zpx(8f))) {
                TennisText(n, TennisTokens.Type.tileNumberSmall, maxLines = 1)
                TennisText(label, TennisTokens.Type.tileFigureLabel, maxLines = 2)
            }
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
        // Chris, 17 Nov: the key figures first, against his average
        if (me != null) { KeyFigures(v, me); Spacer(Modifier.height(zpx(16f))) }
        // Chris, 17 Nov (less text): the session in four small tiles, then the details in short rows
        SessionTiles(v)
        Spacer(Modifier.height(zpx(6f)))
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
        v.rejects?.takeIf { it.total > 0 }?.let { r ->
            // TV-ADJ-06: what was left out (other courts' balls and people, strays), largest first;
            // the full report (rejects/rejects.html) opens from here once the app reads from the cloud (TV-PH-4)
            TextRow("${r.total} detections left out", r.counts.take(3).joinToString(" · ") { "${it.first} ${it.second}" })
        }
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

/** Design v2, court B (Chris, 17 Nov): the filter bar instead of three rows of words; the map gets the room. */
@Composable
private fun VisionCourt(v: VisionSession, f: VisionFilter) {
    val nav = LocalNav.current
    val app = LocalApp.current
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    PivotColumn {
        CourtB(v, answer, f) { sh -> nav.open(Screen.VisionShot(v.id, sh.rally, sh.index)) }
    }
}

internal fun DrawScope.drawCourtTopDown(map: (Double, Double) -> Offset, s: Float) {
    val line = TennisTokens.Colors.primary.copy(alpha = TennisTokens.Vision.lineAlpha)
    Court.lines.forEach { l -> drawLine(line, map(l[0], l[1]), map(l[2], l[3]), strokeWidth = maxOf(1f, 0.05f * s)) }
    drawLine(TennisTokens.Colors.primary, map(0.0, -Court.POST_Y), map(0.0, Court.POST_Y), strokeWidth = maxOf(1.5f, 0.08f * s))
}

fun speedColour(ms: Double?): Color {
    val t = TennisTokens.Vision
    val f = (((ms ?: 0.0) * Units.MPH_PER_MS - t.speedLowMph) / (t.speedHighMph - t.speedLowMph)).toFloat().coerceIn(0f, 1f)
    return lerp(TennisTokens.Colors.titleGradientEnd, TennisTokens.Colors.titleGradientStart, f)
}

fun shotLine(s: VisionShot, who: String = s.hitter) = listOfNotNull(
    s.type, who, Units.mph(s.speedContact), s.call.takeIf { it.isNotBlank() && it != "no bounce" },
).joinToString(" · ")

// ---------------------------------------------------------------------------------------------
/**
 * TV-APP-05: an orbitable replay of a rally on a to-scale court. Drawn natively with Compose
 * (a simple perspective camera circling the court) rather than in a WebView with three.js: no
 * JavaScript engine, no extra network permission, and the Metro look is easier to hold to.
 * Drag sideways to orbit, up and down to tilt; drag along the bar below to move through time.
 */
internal class Orbit(azDeg: Double, elDeg: Double, r: Double, val w: Float, val h: Float) {
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

internal fun DrawScope.seg(cam: Orbit, c: Color, a: DoubleArray, b: DoubleArray, wDp: Float) {
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
    // Design v2, trends A (Chris, 17 Nov): the line of choices as selectors that open the flyout.
    // Only what the trend data holds can be chosen: forehands, yours, so those stay plain words.
    var racquetId by remember { mutableStateOf(racquet?.id) }
    var measure by remember { mutableStateOf("both") }
    val shown = d.racquet(racquetId ?: -1) ?: racquet
    val shownJobs = if (shown == null) jobs else d.jobs.filter { it.racquetId == shown.id }
    val o = LocalOverlays.current
    val measures = listOf("both" to "spin and depth", "spin" to "spin effect", "depth" to "depth")
    fun open() = o.panel("trend choices", onReset = { racquetId = racquet?.id; measure = "both" }) {
        TennisText("racquet", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(4f)))
        SegmentStrip(d.active.map { it.id.toString() to it.name.lowercase() }, racquetId?.toString() ?: "") { racquetId = it.toLongOrNull() }
        Spacer(Modifier.height(zpx(10f)))
        TennisText("measures", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(4f)))
        SegmentStrip(measures, measure) { measure = it }
        Spacer(Modifier.height(zpx(10f)))
    }
    SectionHeader("vision · forehands · you")
    // one selector a line: side by side, a long racquet name pushed the second off the screen
    if (shown != null) { Selector(shown.name.lowercase()) { open() }; Spacer(Modifier.height(zpx(6f))) }
    Selector(measures.first { it.first == measure }.second) { open() }
    Spacer(Modifier.height(zpx(4f)))
    TennisText("Synthetic trend for the preview. Tap a choice to change it.", TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(zpx(6f)))
    if (measure != "depth") TrendChart("spin effect, ft shorter", pts.map { it.epochDay to -it.forehandSpinEffect * Units.FT_PER_M }, shownJobs)
    if (measure == "both") Spacer(Modifier.height(zpx(10f)))
    if (measure != "spin") TrendChart("depth, ft short of the baseline", pts.map { it.epochDay to it.forehandDepth * Units.FT_PER_M }, shownJobs)
}

@Composable
internal fun TrendChart(title: String, pts: List<Pair<Long, Double>>, jobs: List<io.github.wotworth.tennis.data.StringJob>,
                        highlight: Long? = null, format: (Double) -> String = { "%.1f".format(Locale.US, it) }, caption: Boolean = true,
                        rollingAverage: Int = 0) {
    val zpx = LocalZpx.current
    val measurer = androidx.compose.ui.text.rememberTextMeasurer()
    val small = io.github.wotworth.tennis.ui.theme.textStyleFor(TennisTokens.Type.listSecondary)
    TennisText(title, TennisTokens.Type.body)
    val d0 = minOf(pts.minOf { it.first }, jobs.minOfOrNull { it.date } ?: Long.MAX_VALUE) - 2
    val d1 = pts.maxOf { it.first } + 2
    // the axis shows the lowest and highest values (Chris, 17 Nov: as they appear elsewhere)
    val vMin = pts.minOf { it.second };  val vMax = pts.maxOf { it.second }
    val span = (vMax - vMin).takeIf { it > 0 } ?: maxOf(kotlin.math.abs(vMax), 1.0)
    val lo = vMin - 0.15 * span;  val hi = vMax + 0.1 * span
    Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.trendHeight))) {
        val left = zpx(26f).toPx(); val bottom = size.height - zpx(14f).toPx(); val top = zpx(14f).toPx()
        fun x(day: Long) = left + ((day - d0).toFloat() / (d1 - d0)) * (size.width - left)
        fun y(v: Double) = bottom - ((v - lo) / (hi - lo)).toFloat() * (bottom - top)
        jobs.filter { it.date in d0..d1 }.forEach { j ->
            val xx = x(j.date)
            drawLine(TennisTokens.Colors.titleGradientStart, Offset(xx, top), Offset(xx, bottom), strokeWidth = 1.5f * density,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * density, 3 * density)))
            val label = io.github.wotworth.tennis.domain.Strings.tensionText(j) + " lb"
            drawText(measurer, io.github.wotworth.tennis.vision.CanvasText.log(label), Offset(xx + 3 * density, 0f), small.copy(color = TennisTokens.Colors.titleGradientStart))
        }
        drawLine(TennisTokens.Colors.disabled, Offset(left, bottom), Offset(size.width, bottom), strokeWidth = density)
        val path = Path()
        pts.forEachIndexed { i, (day, v) -> if (i == 0) path.moveTo(x(day), y(v)) else path.lineTo(x(day), y(v)) }
        drawPath(path, TennisTokens.Colors.primary, style = Stroke(2f * density))
        if (rollingAverage > 1 && pts.size > 2) {
            // the average of the last [rollingAverage] points at each point (Chris, 17 Nov): which way it's heading
            val avg = Path()
            pts.forEachIndexed { i, (day, _) ->
                val m = pts.subList(maxOf(0, i - rollingAverage + 1), i + 1).map { it.second }.average()
                if (i == 0) avg.moveTo(x(day), y(m)) else avg.lineTo(x(day), y(m))
            }
            drawPath(avg, TennisTokens.Colors.secondary, style = Stroke(2.5f * density))
        }
        pts.forEach { (day, v) ->
            if (day == highlight) drawCircle(TennisTokens.Colors.me, 6f * density, Offset(x(day), y(v)))
            else drawCircle(TennisTokens.Colors.primary, 3f * density, Offset(x(day), y(v)))
        }
        drawText(measurer, io.github.wotworth.tennis.vision.CanvasText.log(format(vMax)), Offset(0f, y(vMax) - 8 * density), small)
        drawText(measurer, io.github.wotworth.tennis.vision.CanvasText.log(format(vMin)), Offset(0f, y(vMin) - 8 * density), small)
    }
    if (caption) TennisText("dashed: restrings, with the tension", TennisTokens.Type.listSecondary)
}

// ---------------------------------------------------------------------------------------------
/**
 * TV-APP-04: one shot's card: its figures and a side view of the real path against no spin.
 * Design v2, shot A (Chris, 17 Nov): the hitter's colour, a two-column grid of figures, and an
 * app bar with labelled icons: previous and next shot (in session order), and "looks wrong".
 */
@Composable
fun VisionShotScreen(id: String, rally: Int, index: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val v = app.vision.session(id)
    val s = v?.shot(rally, index)
    if (v == null || s == null) { Page("shot $rally·$index") { TennisText("This shot is not on the phone.", TennisTokens.Type.listPrimary) }; return }
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    val k = v.shots.indexOf(s)
    fun go(d: Int) { v.shots.getOrNull(k + d)?.let { n -> nav.stack[nav.stack.lastIndex] = Screen.VisionShot(id, n.rally, n.index) } }
    val o = LocalOverlays.current
    val actions = listOf(
        LabeledAction(R.drawable.fluent_arrow_up, "previous") { go(-1) },
        LabeledAction(R.drawable.fluent_arrow_down, "next") { go(1) },
        LabeledAction(R.drawable.fluent_flag, "looks wrong") {
            o.menu(*io.github.wotworth.tennis.vision.LOOKS_WRONG_REASONS.map { reason ->
                reason to { app.vision.flag(id, io.github.wotworth.tennis.vision.Feedback.looksWrong(rally, index, reason)) }
            }.toTypedArray())
        },
    )
    PivotFrame("shot $rally·$index", "shot", null, bar = { LabeledAppBar(actions) }) {
        ShotCardA(v, s, answer)
    }
}

@Composable
internal fun SideView(tr: Trajectory, s: VisionShot, colour: Color = speedColour(s.speedContact), caption: Boolean = true) {
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
        drawPath(pathOf(tr.xyz), colour, style = Stroke(2.5f * density))
    }
    if (caption) TennisText("solid: the real path · dashed: the same shot without spin" +
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
