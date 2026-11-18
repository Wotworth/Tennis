package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.components.NumberTile
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.FootageTest
import java.util.Locale
import kotlin.math.roundToInt

/**
 * Footage tests (Chris, 17 Nov): one camera on real footage, to see how well the vision code
 * found the court lines, the ball, bounces and players. One wide tile each on the sessions page.
 */
val TEST_PIVOTS = listOf("summary", "court", "ball", "bounces", "rallies")

@Composable
fun FootageTestTiles() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    app.vision.tests.all.forEach { t ->
        Tile("footage test · ${t.date}", zpx(l.tileMedium * 2 + l.tileGap), zpx(l.tileMedium * 0.75f),
            description = "footage test ${t.title}", onClick = { nav.open(Screen.FootageTest(t.id)) }) {
            TileLines(listOf("${t.title} · ${t.clips.size} rallies", "ball found in ${pct(t.ball.framesWithBall, t.ball.framesInClips)} of frames"))
        }
        Spacer(Modifier.height(zpx(l.tileGap)))
    }
}

private fun pct(a: Int, b: Int) = if (b <= 0) "–" else "${(100.0 * a / b).roundToInt()}%"
private fun f1(x: Double) = String.format(Locale.US, "%.1f", x)
private fun mmss(s: Double) = "%d:%02d".format(Locale.US, (s / 60).toInt(), (s % 60).toInt())

@Composable
fun FootageTestScreen(id: String, initial: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val t = app.vision.tests.get(id) ?: run { Page("footage test") { TennisText("This test is not on the phone.", TennisTokens.Type.listPrimary) }; return }
    PivotScreen(
        "footage test · ${t.date}", TEST_PIVOTS, initial,
        onChange = { i -> nav.stack[nav.stack.lastIndex] = Screen.FootageTest(id, i) },
        bar = { emptyList<BarButton>() },
        onMore = { nav.open(Screen.Settings) },
    ) { i, _ ->
        when (i) {
            0 -> TestSummary(t)
            1 -> TestCourt(t)
            2 -> TestBall(t)
            3 -> TestBounces(t)
            4 -> TestRallies(t)
        }
    }
}

@Composable
private fun TestSummary(t: FootageTest) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    val w = zpx(l.tileMedium)
    PivotColumn {
        TennisText("${t.title}. ${t.source}. One camera: no speeds, spin or 3D, which need two.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(10f)))
        Row {
            NumberTile("${t.clips.size}", "rallies, ${mmss(t.lengthS)}", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile(pct(t.ball.framesWithBall, t.ball.framesInClips), "frames tracked", w, w)
        }
        Spacer(Modifier.height(zpx(l.tileGap)))
        Row {
            NumberTile(t.court.scorecardMedianPx?.let { "${it.roundToInt()} px" } ?: "${(t.court.paintShare * 100).roundToInt()}%",
                if (t.court.scorecardMedianPx != null) "off your lines" else "lines on paint", w, w)
            Spacer(Modifier.width(zpx(l.tileGap)))
            NumberTile("${t.bounces.size}", "bounces found", w, w)
        }
        SectionHeader("court")
        TextRow("found from the lines alone", "lens ${t.court.hfovDeg.roundToInt()}° wide · camera ${f1(kotlin.math.abs(t.court.camera[0]) - 11.885)} m behind the baseline, ${f1(t.court.camera[2])} m up")
        TextRow("${(t.court.paintShare * 100).roundToInt()}% of the drawn lines on paint", "line fit ${f1(t.court.lineRmsPx)} px")
        if (t.court.cornersOutOfView.isNotEmpty()) TextRow("corners out of view", t.court.cornersOutOfView.joinToString(", "))
        SectionHeader("ball")
        val c = t.ball.check
        if (c != null) {
            TextRow("found in ${pct(c.found, c.ballVisible)} of checked frames", "${c.found} of ${c.ballVisible} frames where the ball was visible, out of ${c.framesChecked} checked by hand")
            TextRow("${pct(c.spotsBall, c.spotsChecked)} of tracked spots were the ball", "${c.spotsBall} of ${c.spotsChecked} checked")
            if (c.note.isNotBlank()) TennisText(c.note, TennisTokens.Type.listSecondary)
        }
        TextRow("${t.ball.tracks} ball tracks", "${t.ball.candidates} candidate spots before tracking")
        SectionHeader("players")
        TextRow("both players placed on court in ${pct(t.players.withTwoOnCourt, t.players.samples)} of moments", "${t.players.samples} moments sampled")
        if (t.notes.isNotEmpty()) {
            SectionHeader("notes")
            t.notes.forEach { TennisText(it, TennisTokens.Type.listSecondary); Spacer(Modifier.height(zpx(6f))) }
        }
    }
}

/** The empty court (players removed), with the fitted court lines drawn over it. */
@Composable
private fun TestCourt(t: FootageTest) {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    val img = remember(t.id) { app.vision.tests.image(t.id, t.court.image) }
    val green = TennisTokens.Colors.titleGradientStart
    PivotColumn {
        TennisText("The court with nobody on it (the middle value of every pixel over the video), and the court lines where the code put them.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        Box(Modifier.fillMaxWidth().aspectRatio(t.court.imageWidth.toFloat() / t.court.imageHeight)) {
            if (img != null) Image(img.asImageBitmap(), "empty court", Modifier.fillMaxWidth().aspectRatio(t.court.imageWidth.toFloat() / t.court.imageHeight), contentScale = ContentScale.FillBounds)
            Canvas(Modifier.fillMaxWidth().aspectRatio(t.court.imageWidth.toFloat() / t.court.imageHeight)) {
                val s = size.width / t.court.imageWidth
                val stroke = zpx(TennisTokens.Vision.testLineWidth).toPx()
                t.court.lines.forEach { pl ->
                    if (pl.size >= 2) {
                        val p = Path()
                        p.moveTo(pl[0].first * s, pl[0].second * s)
                        pl.drop(1).forEach { (x, y) -> p.lineTo(x * s, y * s) }
                        drawPath(p, green, style = Stroke(stroke))
                    }
                }
            }
        }
        Spacer(Modifier.height(zpx(8f)))
        TextRow("lens ${t.court.hfovDeg.roundToInt()}° wide", "fitted with the camera's position, from the lines alone (a phone's lens isn't calibrated)")
        TextRow("camera ${f1(kotlin.math.abs(t.court.camera[0]) - 11.885)} m behind the baseline", "${f1(t.court.camera[2])} m up, ${f1(kotlin.math.abs(t.court.camera[1]))} m off centre")
        t.court.scorecardMedianPx?.let { m ->
            TextRow("${m.roundToInt()} px from your hand-drawn court", "median over 8 points: corners, service line ends, the T · each: " +
                t.court.scorecardPoints.joinToString(" ") { it.roundToInt().toString() } + " px")
        }
        if (t.court.cornersOutOfView.isNotEmpty()) TextRow("out of view", t.court.cornersOutOfView.joinToString(", "))
    }
}

/** Sample frames, people pixelated: the ball ringed where found, its last half second dotted. */
@Composable
private fun TestBall(t: FootageTest) {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    var i by remember { mutableIntStateOf(0) }
    if (t.frames.isEmpty()) { PivotColumn { TennisText("No sample frames.", TennisTokens.Type.listSecondary) }; return }
    val f = t.frames[i.coerceIn(0, t.frames.lastIndex)]
    val img = remember(t.id, f.file) { app.vision.tests.image(t.id, f.file) }
    PivotColumn {
        TennisText("Ring: the ball found in this frame. Dots: where it was over the last half second. Swipe for the next frame.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        var drag = 0f
        Box(Modifier.fillMaxWidth().aspectRatio(16f / 9f).pointerInput(t.id) {
            detectHorizontalDragGestures(onDragEnd = {
                if (drag < -40) i = (i + 1) % t.frames.size
                if (drag > 40) i = (i - 1 + t.frames.size) % t.frames.size
                drag = 0f
            }) { _, d -> drag += d }
        }) {
            if (img != null) Image(img.asImageBitmap(), f.caption, Modifier.fillMaxWidth().aspectRatio(16f / 9f), contentScale = ContentScale.FillBounds)
        }
        Spacer(Modifier.height(zpx(8f)))
        TextRow("frame ${i + 1} of ${t.frames.size} · ${if (f.clip > 0) "rally ${f.clip}" else "between rallies"} · ${mmss(f.t)}", listOf(f.verdict, f.caption).filter { it.isNotBlank() }.joinToString(" · "))
        TextRow("next frame", null) { i = (i + 1) % t.frames.size }
    }
}

/** Bounces placed on the ground through the fitted camera; in or out of the singles court. */
@Composable
private fun TestBounces(t: FootageTest) {
    val zpx = LocalZpx.current
    val v = TennisTokens.Vision
    val inC = TennisTokens.Colors.titleGradientStart
    val outC = TennisTokens.Colors.secondary
    PivotColumn {
        val lengthM = 2 * (Court.HALF_LENGTH + v.courtMarginM)
        val widthM = 2 * (Court.HALF_DOUBLES + v.courtMarginM)
        Canvas(Modifier.fillMaxWidth().height(zpx(v.courtMapHeight))) {
            val pad = zpx(v.courtSidePadding).toPx()
            val s = minOf((size.width - 2 * pad) / widthM.toFloat(), (size.height - 2 * pad) / lengthM.toFloat())
            val cx = size.width / 2;  val cy = size.height / 2
            // the camera's end at the bottom
            val flip = if (t.court.camera[0] > 0) -1.0 else 1.0
            val map = { x: Double, y: Double -> Offset(cx + (flip * y * s).toFloat(), cy - (flip * x * s).toFloat()) }
            drawCourtTopDown(map, s)
            val r = zpx(v.spotRadius).toPx()
            t.bounces.forEach { b ->
                val p = map(b.x, b.y)
                if (b.call == "in") drawCircle(inC, r, p) else drawCircle(outC, r, p, style = Stroke(r / 2))
            }
        }
        Spacer(Modifier.height(zpx(6f)))
        val ins = t.bounces.count { it.call == "in" }
        TennisText("${t.bounces.size} bounces: $ins in (filled), ${t.bounces.size - ins} out (rings), against the singles court. The camera is at the bottom. One camera can't tell a bounce from a hit near the ground, so some dots are hits.", TennisTokens.Type.listSecondary)
    }
}

@Composable
private fun TestRallies(t: FootageTest) {
    PivotColumn {
        t.clips.forEach { c ->
            TextRow("rally ${c.index} · ${mmss(c.startS)} · ${f1(c.lengthS)} s",
                "ball tracked in ${pct(c.framesWithBall, c.frames)} of frames · ${c.tracks} tracks · ${c.bounces} bounces")
        }
    }
}
