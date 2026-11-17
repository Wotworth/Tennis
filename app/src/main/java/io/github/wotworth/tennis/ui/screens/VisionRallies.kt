package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.textStyleFor
import io.github.wotworth.tennis.vision.CanvasText
import io.github.wotworth.tennis.vision.Units
import io.github.wotworth.tennis.vision.VisionRally
import io.github.wotworth.tennis.vision.VisionSession
import kotlin.math.sign

/*
 * Chris, 17 Nov: the 3D tab lists the rallies, each drawn in perspective with every shot in its
 * hitter's colour (you green, your opponent blue) and both ends labelled; tap one for its replay,
 * which plays at real speed, with its shots and its heart rate underneath. Your end is always
 * the near one, so the pictures read the same way whichever end you played from.
 */

/** Which end of the court you played from in this rally: -1 or +1 along the court (0: unknown). */
fun mySide(v: VisionSession, rally: Int, answer: String?): Int {
    val shots = v.shots.filter { it.rally == rally && it.contact.isNotEmpty() }
    val mine = shots.filter { v.who(it.hitter, answer) == "you" }.map { it.contact[0] }
    if (mine.isNotEmpty()) return sign(mine.sorted()[mine.size / 2]).toInt()
    val theirs = shots.map { it.contact[0] }
    return if (theirs.isEmpty()) 0 else -sign(theirs.sorted()[theirs.size / 2]).toInt()
}

/** The camera's starting direction: behind your end, a little to the side. */
private fun startAzimuth(side: Int) = (if (side < 0) 180f else 0f) + TennisTokens.Vision.rallyViewSideDeg

/** The 3D tab: every rally, in perspective, colour-coded; tap one to replay it. */
@Composable
fun VisionRallyList(v: VisionSession) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    PivotColumn {
        TennisText("Your shots green, your opponent's blue. Tap a rally to replay it.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        v.rallies.forEach { r ->
            val open = { nav.open(Screen.VisionRally(v.id, r.index)) }
            RallyView(v, r.index, answer, null, startAzimuth(mySide(v, r.index, answer)), TennisTokens.Vision.view3dStartElevationDeg,
                Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.rallyThumbHeight)).pointerInput(r.index) { detectTapGestures { open() } })
            TextRow("rally ${r.index} · ${r.shots} shots", rallyLine(r), onClick = open)
            Spacer(Modifier.height(zpx(6f)))
        }
    }
}

private fun rallyLine(r: VisionRally) = listOf("ended ${r.ending}", "fastest ${Units.mph(r.fastest)}").joinToString(" · ")

/**
 * A rally on the to-scale court, seen in perspective from azimuth [az] and elevation [el]: the
 * court and net, "you" behind your end, and each shot's path in its hitter's
 * colour, up to the time [now] (seconds, the session's clock), or the whole rally when null.
 */
@Composable
fun RallyView(v: VisionSession, rally: Int, answer: String?, now: Double?, az: Float, el: Float, modifier: Modifier) {
    val t = TennisTokens.Vision
    val measurer = rememberTextMeasurer()
    val label = textStyleFor(TennisTokens.Type.listSecondary)
    val side = mySide(v, rally, answer)
    val trajs = v.trajectories.filter { it.rally == rally }
    Canvas(modifier.clipToBounds()) {
        val (cam, shift) = fitted(az.toDouble(), el.toDouble(), size.width, size.height)
        translate(shift.x, shift.y) {
        val line = TennisTokens.Colors.primary.copy(alpha = t.lineAlpha)
        Court.lines.forEach { l -> seg(cam, line, doubleArrayOf(l[0], l[1], 0.0), doubleArrayOf(l[2], l[3], 0.0), 1.5f) }
        seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, -Court.POST_Y, Court.NET_POST), doubleArrayOf(0.0, 0.0, Court.NET_CENTRE), 2f)
        seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, 0.0, Court.NET_CENTRE), doubleArrayOf(0.0, Court.POST_Y, Court.NET_POST), 2f)
        for (y in listOf(-Court.POST_Y, Court.POST_Y)) seg(cam, TennisTokens.Colors.primary, doubleArrayOf(0.0, y, 0.0), doubleArrayOf(0.0, y, Court.NET_POST), 2f)
        // only your end is labelled: your opponent's is the other one (Chris, 17 Nov)
        if (side != 0) endLabel(cam, measurer, "you", side, TennisTokens.Colors.me, label)
        trajs.forEach { tr ->
            val shot = v.shot(tr.rally, tr.shot)
            val c = if (shot != null && v.who(shot.hitter, answer) == "you") TennisTokens.Colors.me else TennisTokens.Colors.opponent
            val n = if (now == null) tr.xyz.size - 1 else ((now - tr.t0) / tr.dt).toInt().coerceIn(-1, tr.xyz.size - 1)
            if (n < 1) return@forEach
            val path = Path()
            var started = false
            for (i in 0..n) cam.screen(tr.xyz[i])?.let { if (!started) { path.moveTo(it.x, it.y); started = true } else path.lineTo(it.x, it.y) }
            drawPath(path, c, style = Stroke(2.2f * density))
            if (now != null && now <= tr.t0 + tr.dt * (tr.xyz.size - 1)) cam.screen(tr.xyz[n])?.let { drawCircle(TennisTokens.Colors.primary, 4f * density, it) }
        }
        }
    }
}

/**
 * The closest camera (from rallyViewDistanceM outwards) whose picture of the court and both end
 * labels fits the box, and the shift that centres that picture in it.
 */
private fun fitted(az: Double, el: Double, w: Float, h: Float): Pair<Orbit, Offset> {
    val t = TennisTokens.Vision
    val xe = Court.HALF_LENGTH + t.endLabelM + 1.0
    val pts = listOf(-1.0, 1.0).flatMap { sx -> listOf(-1.0, 1.0).map { sy -> doubleArrayOf(sx * xe, sy * Court.HALF_DOUBLES, 0.0) } } +
        listOf(doubleArrayOf(0.0, -Court.POST_Y, Court.NET_POST), doubleArrayOf(0.0, Court.POST_Y, Court.NET_POST))
    val m = 0.04f
    var r = t.rallyViewDistanceM.toDouble()
    while (true) {
        val cam = Orbit(az, el, r, w, h)
        val p = pts.map { cam.screen(it) }
        if (p.all { it != null } || r > 120.0) {
            val q = p.filterNotNull()
            val x0 = q.minOf { it.x }; val x1 = q.maxOf { it.x }; val y0 = q.minOf { it.y }; val y1 = q.maxOf { it.y }
            if ((x1 - x0 <= w * (1 - 2 * m) && y1 - y0 <= h * (1 - 2 * m)) || r > 120.0)
                return cam to Offset(w / 2 - (x0 + x1) / 2, h / 2 - (y0 + y1) / 2)
        }
        r += 0.5
    }
}

private fun DrawScope.endLabel(cam: Orbit, m: TextMeasurer, text: String, side: Int, c: androidx.compose.ui.graphics.Color,
                               style: androidx.compose.ui.text.TextStyle) {
    val p = cam.screen(doubleArrayOf(side * (Court.HALF_LENGTH + TennisTokens.Vision.endLabelM), 0.0, 0.0)) ?: return
    val lay = m.measure(CanvasText.log(text), style.copy(color = c))
    drawText(lay, topLeft = Offset(p.x - lay.size.width / 2f, p.y - lay.size.height / 2f))
}

/**
 * One rally's replay (Chris, 17 Nov): play at real speed (pressed at the end, it starts again),
 * back and forward one shot, restart; drag the court to turn it and the bar to move through
 * time. Underneath: the rally's shots and its heart rate.
 */
@Composable
fun VisionRallyScreen(id: String, rally: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    val v = app.vision.session(id)
    val r = v?.rallies?.firstOrNull { it.index == rally }
    if (v == null || r == null) { io.github.wotworth.tennis.ui.components.Page("rally $rally") { TennisText("This rally is not on the phone.", TennisTokens.Type.listPrimary) }; return }
    val answer = if (v.sample) app.prefs.visionSampleIdentity else null
    val trajs = v.trajectories.filter { it.rally == rally }.sortedBy { it.t0 }
    val t0 = trajs.minOfOrNull { it.t0 } ?: r.start
    val t1 = trajs.maxOfOrNull { it.t0 + it.dt * (it.xyz.size - 1) } ?: r.stop
    var now by remember(rally) { mutableDoubleStateOf(t1) }
    var playing by remember(rally) { mutableStateOf(false) }
    var az by remember(rally) { mutableFloatStateOf(startAzimuth(mySide(v, rally, answer))) }
    var el by remember(rally) { mutableFloatStateOf(t.view3dStartElevationDeg) }
    LaunchedEffect(playing) {
        if (!playing) return@LaunchedEffect
        if (now >= t1) now = t0
        var last = withFrameNanos { it }
        while (playing) {
            withFrameNanos { n -> now = (now + (n - last) / 1e9).coerceAtMost(t1); last = n }
            if (now >= t1) playing = false
        }
    }
    val starts = trajs.map { it.t0 }
    fun step(d: Int) {
        playing = false
        val k = starts.indexOfLast { it <= now + 1e-6 }
        now = when {
            d < 0 -> starts.getOrNull(if (k > 0 && now - starts[k] < 0.3) k - 1 else maxOf(k, 0)) ?: t0
            else -> starts.getOrNull(k + 1) ?: t1
        }
    }
    val current = trajs.lastOrNull { it.t0 <= now }?.let { v.shot(it.rally, it.shot) }
    val bar = listOf(
        LabeledAction(R.drawable.fluent_arrow_counterclockwise, "restart") { now = t0; playing = true },
        LabeledAction(R.drawable.fluent_previous, "back a shot") { step(-1) },
        if (playing) LabeledAction(R.drawable.fluent_pause, "pause") { playing = false }
        else LabeledAction(R.drawable.fluent_play, "play") { playing = true },
        LabeledAction(R.drawable.fluent_next, "next shot") { step(1) },
    )
    PivotFrame("${visionDay(v)} · rally ${r.index}", "3D", null, bar = { LabeledAppBar(bar) }) {
        RallyView(v, rally, answer, now, az, el, Modifier.fillMaxWidth().height(zpx(t.view3dHeight)).pointerInput(rally) {
            detectDragGestures { _, d -> az -= d.x * 0.3f; el = (el + d.y * 0.2f).coerceIn(5f, 85f) }
        })
        Spacer(Modifier.height(zpx(8f)))
        val f = if (t1 > t0) ((now - t0) / (t1 - t0)).toFloat().coerceIn(0f, 1f) else 1f
        Canvas(Modifier.fillMaxWidth().height(zpx(t.scrubberHeight)).pointerInput(t0, t1) {
            detectDragGestures(onDragStart = { p -> playing = false; now = t0 + (t1 - t0) * (p.x / size.width).coerceIn(0f, 1f) }) { c, _ ->
                now = t0 + (t1 - t0) * (c.position.x / size.width).coerceIn(0f, 1f)
            }
        }.pointerInput(t0, t1) { detectTapGestures { p -> playing = false; now = t0 + (t1 - t0) * (p.x / size.width).coerceIn(0f, 1f) } }) {
            val y = size.height / 2
            drawLine(TennisTokens.Colors.disabled, Offset(0f, y), Offset(size.width, y), strokeWidth = 2f * density)
            drawLine(TennisTokens.Colors.primary, Offset(0f, y), Offset(size.width * f, y), strokeWidth = 2f * density)
            starts.forEach { s0 ->
                val x = if (t1 > t0) ((s0 - t0) / (t1 - t0)).toFloat() * size.width else 0f
                drawLine(TennisTokens.Colors.secondary, Offset(x, y - 6 * density), Offset(x, y + 6 * density), strokeWidth = 1.5f * density)
            }
            drawRect(TennisTokens.Colors.primary, Offset(size.width * f - 4 * density, y - 10 * density), Size(8 * density, 20 * density))
        }
        current?.let { TennisText(shotLine(it, v.who(it.hitter, answer)), TennisTokens.Type.listSecondary) }
        TennisText("Drag the court to turn it; drag the bar to move through the rally. Ticks: each shot.", TennisTokens.Type.listSecondary)
        SectionHeader("shots")
        v.shots.filter { it.rally == rally }.forEach { s -> ShotRow(v, s, answer) { nav.open(Screen.VisionShot(v.id, s.rally, s.index)) } }
        SmallAction("missed a shot?") { nav.open(Screen.MissedShot(v.id, rally)) }
        SectionHeader("heart rate")
        RallyHeart(v, r)
    }
}

/** The rally's heart rate: its peak while the point was played, and how far it fell before the next one. */
@Composable
private fun RallyHeart(v: VisionSession, r: VisionRally) {
    val next = v.rallies.firstOrNull { it.index > r.index }
    val during = v.heartRate.filter { it.t >= r.start && it.t <= r.stop }.map { it.bpm }
    val after = v.heartRate.filter { it.t > r.stop && it.t <= (next?.start ?: (r.stop + TennisTokens.Vision.recoveryWindowS)) }.map { it.bpm }
    if (during.isEmpty()) {
        TennisText("No heart rate for this rally: the watch didn't record during it.", TennisTokens.Type.listSecondary)
        return
    }
    TextRow("${during.max()} bpm", "highest in the rally")
    if (after.isNotEmpty()) TextRow("${after.min()} bpm", if (next != null) "lowest before the next point" else "lowest after the last point")
}
