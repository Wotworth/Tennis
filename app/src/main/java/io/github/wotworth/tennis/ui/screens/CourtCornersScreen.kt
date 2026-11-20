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
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
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
import io.github.wotworth.tennis.vision.CornerSnap
import io.github.wotworth.tennis.vision.cornersTappedText
import kotlin.math.roundToInt

/** What the page says above the picture. */
internal fun cornerPrompt(c: CornerCheck): String {
    val how = "the four corners of the doubles court (where each baseline meets the outer sideline). " +
        "Each tap snaps to the corner of the paint; drag a ring if it picked the wrong one. Pinch to zoom."
    return if (c.reason == "taps") "Camera ${c.cam} · the last four taps did not make a court from this camera. Tap $how"
    else "Camera ${c.cam} · the yellow-green lines are the court as the PC placed it, with paint under " +
        "${(100 * c.support).roundToInt()}% of them. If they sit on the court's own lines, say so below. If not, tap $how"
}

/** One corner on the picture: where it is now, and how it got there. */
internal data class TapCorner(val p: Offset, val how: How) {
    enum class How { SNAPPED, NOT_SNAPPED, MOVED }
}

/**
 * Adds a tap to the corners: a tap near a ring moves that ring; with four rings any tap moves the
 * nearest; otherwise it is a new corner. [near]: how close counts as "near", in picture pixels.
 * [snap] turns a tap into the corner of the paint there, or null when nothing convincing is found.
 */
internal fun placeCorner(taps: List<TapCorner>, p: Offset, near: Float, snap: (Offset) -> Offset? = { null }): List<TapCorner> {
    val s = snap(p)
    val c = if (s != null) TapCorner(s, TapCorner.How.SNAPPED) else TapCorner(p, TapCorner.How.NOT_SNAPPED)
    val i = taps.indices.minByOrNull { (taps[it].p - p).getDistance() }
    return if (i != null && (taps.size == 4 || (taps[i].p - p).getDistance() <= near)) taps.toMutableList().also { it[i] = c }
    else taps + c
}

/** The ring a finger came down on, if any (within [near] picture pixels). */
internal fun ringAt(taps: List<TapCorner>, p: Offset, near: Float): Int? =
    taps.indices.filter { (taps[it].p - p).getDistance() <= near }.minByOrNull { (taps[it].p - p).getDistance() }

/** Below the picture: how many corners, and any that are not on the paint's corner, in words. */
internal fun cornerStatus(taps: List<TapCorner>): String {
    val words = listOf("none", "one", "two", "three", "four")
    val n = taps.count { it.how == TapCorner.How.NOT_SNAPPED };  val m = taps.count { it.how == TapCorner.How.MOVED }
    return listOfNotNull(cornersTappedText(taps.size),
        if (n > 0) "${words[n]} not snapped" else null,
        if (m > 0) "${words[m]} moved by hand" else null).joinToString(" · ")
}

/**
 * "Court corners" (Chris, 19 and 20 Nov; TV-CAL-21, 22): the picture of the empty court from a camera
 * whose court-line fit the PC doubts, with that fit drawn over it. Chris taps the four corners of the
 * doubles court in any order. Each tap snaps to where the two lines' paint crosses, at their outside
 * edges (CornerSnap); a ring that did not snap is drawn dashed. A ring can be dragged; while a finger
 * is down a magnifier above it shows what is under it, with a crosshair. Pinch to zoom; zoomed in,
 * one finger pans (away from the rings). Or he says the drawn lines are right.
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
        val image = remember(img) { img?.asImageBitmap() }
        val pixels = remember(img) { img?.let { b -> IntArray(b.width * b.height).also { b.getPixels(it, 0, b.width, 0, 0, b.width, b.height) } } }
        val snap: (Offset) -> Offset? = { p -> if (img == null || pixels == null) null else CornerSnap.snap(pixels, img.width, img.height, p)?.corner }
        var taps by remember(c.id) { mutableStateOf(VisionDefaults.cornerPreview.map { placeCorner(emptyList(), it, 0f, snap).single() }) }
        var showLines by remember(c.id) { mutableStateOf(true) }
        var zoom by remember(c.id) { mutableFloatStateOf(1f) }
        var pan by remember(c.id) { mutableStateOf(Offset.Zero) }
        var finger by remember(c.id) { mutableStateOf<Offset?>(null) }      // where a finger is down (box px), for the loupe
        TennisText(cornerPrompt(c), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        val ring = zpx(v.cornerRing)
        Box(Modifier.fillMaxWidth().aspectRatio(c.width.toFloat() / c.height).clipToBounds()
            .testTag("cornerPicture")
            .semantics { stateDescription = "corners ${taps.size} zoom $zoom lines $showLines loupe ${finger != null} snapped ${taps.count { it.how == TapCorner.How.SNAPPED }}" }
            .pointerInput(c.id) {
                awaitEachGesture {
                    val first = awaitFirstDown(requireUnconsumed = false)
                    val box = size.toSize()
                    val near = 2 * ring.toPx() / zoom / box.width * c.width               // two ring widths on the screen
                    val dragging = ringAt(taps, CornerGeometry.toPicture(first.position, box, zoom, pan, c.width, c.height), near)
                    var moved = false;  var pinched = false
                    finger = first.position
                    while (true) {
                        val e = awaitPointerEvent()
                        if (e.changes.none { it.pressed }) break
                        if (e.changes.count { it.pressed } >= 2) {
                            // keep the point under the fingers where it is, then follow the fingers
                            val (nz, np) = CornerGeometry.pinch(zoom, pan, e.calculateZoom(), e.calculateCentroid(useCurrent = true), e.calculatePan(), box, v.cornerMaxZoom)
                            zoom = nz;  pan = np;  pinched = true;  finger = null
                            e.changes.forEach { it.consume() }
                            continue
                        }
                        val ch = e.changes.first { it.pressed }
                        if ((ch.position - first.position).getDistance() > viewConfiguration.touchSlop) moved = true
                        if (!pinched) finger = ch.position
                        if (!moved || pinched) continue
                        if (dragging != null) {
                            // a ring follows the finger; where it is let go is where Chris put it
                            val q = CornerGeometry.toPicture(ch.position, box, zoom, pan, c.width, c.height)
                            taps = taps.toMutableList().also { it[dragging] = TapCorner(q, TapCorner.How.MOVED) }
                            ch.consume()
                            continue
                        }
                        if (zoom == 1f) { finger = null; break }      // not zoomed: the page scrolls
                        finger = null
                        pan = CornerGeometry.clamp(pan + (ch.position - ch.previousPosition), zoom, box)
                        ch.consume()
                    }
                    finger = null
                    if (!moved && !pinched) {
                        val p = CornerGeometry.toPicture(first.position, box, zoom, pan, c.width, c.height)
                        taps = placeCorner(taps, p, near, snap)
                    }
                }
            }) {
            if (image != null) Image(image, "camera ${c.cam}: the empty court", Modifier.fillMaxSize().graphicsLayer {
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
                val dash = PathEffect.dashPathEffect(floatArrayOf(4 * w, 3 * w))
                taps.forEach { t ->
                    val q = CornerGeometry.toBox(t.p, size, zoom, pan, c.width, c.height)
                    val fx = if (t.how == TapCorner.How.NOT_SNAPPED) dash else null
                    drawCircle(TennisTokens.Colors.background, ring.toPx(), q, style = Stroke(2.2f * w, pathEffect = fx))
                    drawCircle(TennisTokens.Colors.primary, ring.toPx(), q, style = Stroke(w, pathEffect = fx))
                    drawCircle(TennisTokens.Colors.primary, zpx(v.cornerDot).toPx(), q)
                }
                // the loupe: what is under the finger, magnified, above the finger, with a crosshair
                val f = finger ?: VisionDefaults.cornerLoupePreview?.let { CornerGeometry.toBox(it, size, zoom, pan, c.width, c.height) }
                if (f != null && image != null) {
                    val lr = zpx(v.loupeRadius).toPx()
                    val shown = size.width / c.width * zoom                       // screen px per picture px now
                    val mag = shown * v.loupeMag
                    val at = CornerGeometry.toPicture(f, size, zoom, pan, c.width, c.height)
                    var centre = Offset(f.x, f.y - 1.7f * lr)
                    if (centre.y - lr < 0) centre = Offset(f.x, f.y + 1.7f * lr)
                    centre = Offset(centre.x.coerceIn(lr, size.width - lr), centre.y)
                    val half = lr / mag
                    val circle = Path().apply { addOval(androidx.compose.ui.geometry.Rect(centre, lr)) }
                    clipPath(circle) {
                        drawRect(TennisTokens.Colors.background, centre - Offset(lr, lr), Size(2 * lr, 2 * lr))
                        val sx = (at.x - half).toInt();  val sy = (at.y - half).toInt()
                        val n = (2 * half).toInt().coerceAtLeast(1)
                        val ox = (at.x - half - sx) * mag;  val oy = (at.y - half - sy) * mag
                        val cx = sx.coerceIn(0, (image.width - n).coerceAtLeast(0));  val cy = sy.coerceIn(0, (image.height - n).coerceAtLeast(0))
                        drawImage(image, IntOffset(cx, cy), IntSize(n.coerceAtMost(image.width), n.coerceAtMost(image.height)),
                            IntOffset((centre.x - lr - ox + (cx - sx) * mag).toInt(), (centre.y - lr - oy + (cy - sy) * mag).toInt()),
                            IntSize((n * mag).toInt(), (n * mag).toInt()), filterQuality = androidx.compose.ui.graphics.FilterQuality.None)
                        // the rings inside the loupe too
                        taps.forEach { t -> drawCircle(TennisTokens.Colors.primary, zpx(v.cornerDot).toPx() * 1.5f, centre + (t.p - at) * mag) }
                    }
                    drawCircle(TennisTokens.Colors.primary, lr, centre, style = Stroke(w))
                    val g = lr * 0.35f
                    drawLine(TennisTokens.Colors.primary, centre - Offset(g, 0f), centre - Offset(g * 0.25f, 0f), w)
                    drawLine(TennisTokens.Colors.primary, centre + Offset(g * 0.25f, 0f), centre + Offset(g, 0f), w)
                    drawLine(TennisTokens.Colors.primary, centre - Offset(0f, g), centre - Offset(0f, g * 0.25f), w)
                    drawLine(TennisTokens.Colors.primary, centre + Offset(0f, g * 0.25f), centre + Offset(0f, g), w)
                }
            }
        }
        Spacer(Modifier.height(zpx(8f)))
        TennisText(cornerStatus(taps), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        MetroButton("use these corners", enabled = taps.size == 4) { app.vision.answerCorners(c, CornerAnswer.Corners(taps.map { it.p })) }
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
