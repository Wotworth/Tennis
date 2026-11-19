package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.toSize
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.components.MetroButton
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.CornerAnswer
import io.github.wotworth.tennis.vision.CornerCheck
import io.github.wotworth.tennis.vision.CornerGeometry
import io.github.wotworth.tennis.vision.cornersTappedText
import kotlin.math.roundToInt

/** What the page says above the picture. */
internal fun cornerPrompt(c: CornerCheck): String {
    val how = "the four corners of the doubles court (where each baseline meets the outer sideline). " +
        "Pinch to zoom in; a tap near a ring moves it."
    return if (c.reason == "taps") "Camera ${c.cam} · the last four taps did not make a court from this camera. Tap $how"
    else "Camera ${c.cam} · the yellow-green lines are the court as the PC placed it, with paint under " +
        "${(100 * c.support).roundToInt()}% of them. If they sit on the court's own lines, say so below. If not, tap $how"
}

/**
 * Adds a tap to the corners: a tap near a ring moves that ring; with four rings any tap moves the
 * nearest; otherwise it is a new corner. [near]: how close counts as "near", in picture pixels.
 */
internal fun placeCorner(taps: List<Offset>, p: Offset, near: Float): List<Offset> {
    val i = taps.indices.minByOrNull { (taps[it] - p).getDistance() }
    return if (i != null && (taps.size == 4 || (taps[i] - p).getDistance() <= near)) taps.toMutableList().also { it[i] = p }
    else taps + p
}

/**
 * "Court corners" (Chris, 19 Nov; TV-CAL-21, 22): the picture of the empty court from a camera whose
 * court-line fit the PC doubts, with that fit drawn over it. Chris taps the four corners of the
 * doubles court (in any order; pinch to zoom, one finger pans when zoomed, a tap near a ring moves
 * it) or says the drawn lines are right. The PC then places the camera from the taps and runs the
 * held session on.
 */
@Composable
fun CourtCornersScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val v = TennisTokens.Vision
    val checks = app.vision.cornerChecks(app.prefs.visionSample)
    Page("court corners") {
        val c = checks.firstOrNull()
        if (c == null) {
            TennisText("Nothing is waiting. When a session's court lines cannot be trusted, its picture comes here.", TennisTokens.Type.body)
            Spacer(Modifier.height(zpx(12f)))
            MetroButton("done") { nav.back() }
            return@Page
        }
        val img = remember(c.id) { app.vision.cornerImage(c) }
        var taps by remember(c.id) { mutableStateOf(VisionDefaults.cornerPreview) }
        var showLines by remember(c.id) { mutableStateOf(true) }
        var zoom by remember(c.id) { mutableFloatStateOf(1f) }
        var pan by remember(c.id) { mutableStateOf(Offset.Zero) }
        TennisText(cornerPrompt(c), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        val ring = zpx(v.cornerRing)
        Box(Modifier.fillMaxWidth().aspectRatio(c.width.toFloat() / c.height).clipToBounds()
            .testTag("cornerPicture")
            .semantics { stateDescription = "corners ${taps.size} zoom $zoom lines $showLines" }
            .pointerInput(c.id) {
                awaitEachGesture {
                    val first = awaitFirstDown(requireUnconsumed = false)
                    val box = size.toSize()
                    var moved = false;  var pinched = false
                    while (true) {
                        val e = awaitPointerEvent()
                        if (e.changes.none { it.pressed }) break
                        if (e.changes.count { it.pressed } >= 2) {
                            // keep the point under the fingers where it is, then follow the fingers
                            val (nz, np) = CornerGeometry.pinch(zoom, pan, e.calculateZoom(), e.calculateCentroid(useCurrent = true), e.calculatePan(), box, v.cornerMaxZoom)
                            zoom = nz;  pan = np;  pinched = true
                            e.changes.forEach { it.consume() }
                            continue
                        }
                        val ch = e.changes.first { it.pressed }
                        if ((ch.position - first.position).getDistance() > viewConfiguration.touchSlop) moved = true
                        if (!moved || pinched) continue
                        if (zoom == 1f) break                      // not zoomed: the page scrolls
                        pan = CornerGeometry.clamp(pan + (ch.position - ch.previousPosition), zoom, box)
                        ch.consume()
                    }
                    if (!moved && !pinched) {
                        val p = CornerGeometry.toPicture(first.position, box, zoom, pan, c.width, c.height)
                        // "near a ring": two ring widths on the screen, whatever the zoom
                        val near = 2 * ring.toPx() / zoom / box.width * c.width
                        taps = placeCorner(taps, p, near)
                    }
                }
            }) {
            if (img != null) Image(img.asImageBitmap(), "camera ${c.cam}: the empty court", Modifier.fillMaxSize().graphicsLayer {
                transformOrigin = TransformOrigin(0f, 0f);  scaleX = zoom;  scaleY = zoom;  translationX = pan.x;  translationY = pan.y
            }, contentScale = ContentScale.FillBounds)
            // the fit and the rings keep their width on the screen whatever the zoom
            Canvas(Modifier.fillMaxSize()) {
                val w = zpx(v.cornerStroke).toPx()
                val lw = zpx(v.cornerLine).toPx()
                if (showLines) c.lines.forEach { l ->
                    val path = Path()
                    l.forEachIndexed { i, p ->
                        val q = CornerGeometry.toBox(p, size, zoom, pan, c.width, c.height)
                        if (i == 0) path.moveTo(q.x, q.y) else path.lineTo(q.x, q.y)
                    }
                    drawPath(path, TennisTokens.Colors.titleGradientStart, style = Stroke(lw))
                }
                taps.forEach { p ->
                    val q = CornerGeometry.toBox(p, size, zoom, pan, c.width, c.height)
                    drawCircle(TennisTokens.Colors.background, ring.toPx(), q, style = Stroke(2.2f * w))
                    drawCircle(TennisTokens.Colors.primary, ring.toPx(), q, style = Stroke(w))
                    drawCircle(TennisTokens.Colors.primary, zpx(v.cornerDot).toPx(), q)
                }
            }
        }
        Spacer(Modifier.height(zpx(8f)))
        TennisText(cornersTappedText(taps.size), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        MetroButton("use these corners", enabled = taps.size == 4) { app.vision.answerCorners(c, CornerAnswer.Corners(taps)) }
        Spacer(Modifier.height(zpx(8f)))
        MetroButton("the lines are right") { app.vision.answerCorners(c, CornerAnswer.Accepted) }
        Spacer(Modifier.height(zpx(10f)))
        Row {
            SmallAction("undo last tap", taps.isNotEmpty()) { taps = taps.dropLast(1) }
            Spacer(Modifier.width(zpx(8f)))
            SmallAction("zoom out", zoom > 1f) { zoom = 1f; pan = Offset.Zero }
        }
        Spacer(Modifier.height(zpx(8f)))
        Row {
            SmallAction(if (showLines) "hide the lines" else "show the lines") { showLines = !showLines }
            Spacer(Modifier.width(zpx(8f)))
            SmallAction("stop for now") { nav.back() }
        }
        if (app.prefs.visionSample) {
            Spacer(Modifier.height(zpx(10f)))
            TennisText("Sample picture (synthetic), its lines drawn one alley to the side on purpose. Answers wait on the phone until the cloud is set up.", TennisTokens.Type.listSecondary)
        }
    }
}
