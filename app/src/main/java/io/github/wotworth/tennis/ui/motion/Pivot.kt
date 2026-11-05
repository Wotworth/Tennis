// Copied from the Zune player (Wotworth/zune ui/motion/CategoryPager.kt at f2d9237), package renamed.
// Changes: the bar is a Windows Phone pivot header (v0.3 title, option a): large lowercase headers,
// the selected one filled with the title gradient (VIS-03), positions from TennisTokens.Layout.pivot*.
package io.github.wotworth.tennis.ui.motion

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.snapshots.Snapshot
import kotlinx.coroutines.Job
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import io.github.wotworth.tennis.ui.components.baselineAt
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.applyCase
import io.github.wotworth.tennis.ui.theme.textStyleFor
import io.github.wotworth.tennis.ui.theme.titleGradient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * MOT-20, MOT-21: a category bar whose content follows the finger. [offset] is the drag in
 * screen widths: negative while moving toward the next category, positive toward the previous.
 *
 * MOT-21 (revised): the incoming category's rows are drawn staggered from the first frame they
 * are visible, while the finger drags; on release (or a label tap) they ease into line with no
 * pause. Everything that decides where content is drawn is plain Compose state, and a switch
 * changes it in one snapshot.
 */
@Stable
class CategoryPagerState(val count: Int, initial: Int, private val scope: CoroutineScope, private val onChange: (Int) -> Unit) {
    var selected by mutableIntStateOf(initial)
        private set
    var offset by mutableFloatStateOf(0f)
        private set
    /** MOT-21: the selected category's row stagger, 1 = full (index × 50 zpx), 0 = in line. */
    var stagger by mutableFloatStateOf(0f)
        private set
    /** +1: rows offset to the right (arriving from the right); -1: to the left. */
    var arrivalDirection by mutableIntStateOf(1)
        private set
    /** True while a neighbour is being dragged in (or springs back): its rows are fully staggered. */
    var neighbourStaggered by mutableStateOf(false)
        private set
    internal val labelWidths = mutableStateMapOf<Int, Int>()

    private var offsetJob: Job? = null
    private var staggerJob: Job? = null

    fun next(i: Int, d: Int) = ((i + d) % count + count) % count

    /** Tapping a label: switch at once; rows start staggered and ease into line (MOT-21). */
    fun select(i: Int) {
        if (i == selected) return
        offsetJob?.cancel()
        Snapshot.withMutableSnapshot {
            offset = 0f
            neighbourStaggered = false
            selected = i
            arrivalDirection = 1
            stagger = if (animationsOn()) 1f else 0f
        }
        onChange(i)
        settleStagger()
    }

    private fun settleStagger() {
        staggerJob?.cancel()
        if (!animationsOn()) { stagger = 0f; return }
        staggerJob = scope.launch {
            androidx.compose.animation.core.animate(stagger, 0f, animationSpec = zTween(TennisTokens.Motion.slideInSettleMs, TennisTokens.Easings.expoOut6)) { v, _ -> stagger = v }
        }
    }

    /** MOT-20: content follows the finger 1:1 ([widths] of the screen). */
    internal fun drag(widths: Float) {
        offsetJob?.cancel()
        neighbourStaggered = true
        offset = (offset + widths).coerceIn(-1f, 1f)
    }

    private suspend fun animateOffset(to: Float, ms: Int) {
        androidx.compose.animation.core.animate(offset, to, animationSpec = zTween(ms, TennisTokens.Easings.expoOut6)) { v, _ -> offset = v }
    }

    /** MOT-20: commit past 24% of the width or 380 dp/s, else spring back. */
    internal fun release(velocityWidthsPerS: Float, velocityDpPerS: Float) {
        val m = TennisTokens.Motion
        val o = offset
        val commit = abs(o) > m.swipeCommitFraction || abs(velocityDpPerS) > m.swipeCommitVelocityDpPerS
        val dir = when {
            !commit -> 0
            abs(velocityDpPerS) > m.swipeCommitVelocityDpPerS -> if (velocityWidthsPerS < 0) 1 else -1
            else -> if (o < 0) 1 else -1
        }
        offsetJob?.cancel()
        if (dir == 0) {
            offsetJob = scope.launch {
                animateOffset(0f, m.springBackMs)
                neighbourStaggered = false
            }
            return
        }
        // Commit at once, in one snapshot: the incoming category becomes the selected one exactly
        // where it is (offset shifted by a whole width), with its rows still fully staggered; the
        // old category becomes the neighbour sliding out, in line. Then both settle together.
        val target = next(selected, dir)
        Snapshot.withMutableSnapshot {
            offset = o + dir
            neighbourStaggered = false
            selected = target
            arrivalDirection = dir
            stagger = if (animationsOn()) 1f else 0f
        }
        onChange(target)
        settleStagger()
        offsetJob = scope.launch { animateOffset(0f, m.slideInSettleMs) }
    }
}

@Composable
fun rememberCategoryPager(count: Int, initial: Int, onChange: (Int) -> Unit): CategoryPagerState {
    val scope = rememberCoroutineScope()
    var saved by rememberSaveable { mutableIntStateOf(initial) }
    return remember(count) { CategoryPagerState(count, saved, scope) { saved = it; onChange(it) } }
}

/**
 * NAV-30, NAV-31, MOT-20: the selected label at the left in white, the rest trailing in gray and
 * wrapping. While dragging, the row slides so the neighbouring label arrives exactly at the left
 * when the content has moved a whole width.
 */
@Composable
fun PagerCategoryBar(state: CategoryPagerState, labels: List<String>) {
    val zpx = LocalZpx.current
    val role = TennisTokens.Type.pivotHeader
    val n = labels.size
    val sel = state.selected
    // The previous label sits just off the left edge, so a swipe back can bring it in.
    val order = (-1 until n).map { state.next(sel, it) }
    Box(Modifier.fillMaxWidth().clipToBounds()) {
        Row(
            Modifier
                // Measured as wide as it likes, laid out within the screen width, clipped by the Box.
                .layout { m, c ->
                    val p = m.measure(c.copy(maxWidth = Constraints.Infinity))
                    val prevWidth = state.labelWidths[-1] ?: 0
                    layout(c.maxWidth, p.height) { p.place(zpx(TennisTokens.Layout.pivotHeaderLeft).roundToPx() - prevWidth, 0) }
                }
                .graphicsLayer {
                    val o = state.offset
                    val toNext = state.labelWidths[0] ?: 0
                    val toPrev = state.labelWidths[-1] ?: 0
                    translationX = if (o < 0) o * toNext else o * toPrev
                },
        ) {
            order.forEachIndexed { pos, i ->
                val slot = pos - 1
                val style = textStyleFor(role).let { if (slot == 0) it else it.copy(color = TennisTokens.Colors.secondary) }
                BasicText(
                    applyCase(labels[i], role.case) + " ",
                    style = style,
                    maxLines = 1,
                    softWrap = false,
                    onTextLayout = { state.labelWidths[slot] = it.size.width },
                    modifier = Modifier
                        .baselineAt(zpx(TennisTokens.Layout.pivotHeaderBaseline))
                        .then(if (slot == 0) Modifier.titleGradient() else Modifier)
                        // The previous label only shows while swiping back toward it.
                        .then(if (slot < 0) Modifier.graphicsLayer { alpha = if (state.offset > 0f) 1f else 0f } else Modifier)
                        .press(description = labels[i]) { state.select(i) },
                )
            }
        }
    }
}

/** MOT-20: the content area. The current category follows the finger 1:1, with its neighbour beside it. */
@Composable
fun PagerContent(state: CategoryPagerState, content: @Composable (Int) -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .clipToBounds()
            .pointerInput(state) { categorySwipes(state) },
    ) {
        // Only the direction matters for composition; the offset itself is read at draw time.
        val side by androidx.compose.runtime.remember(state) {
            androidx.compose.runtime.derivedStateOf { kotlin.math.sign(state.offset).toInt() }
        }
        val slide = androidx.compose.runtime.remember(state) { SlideIn(state) }
        // The incoming category is drawn at MOT-21's starting offset from its first frame on screen.
        val incoming = androidx.compose.runtime.remember(state) { SlideIn(state, incoming = true) }
        val neighbour = if (side == 0) null else state.next(state.selected, -side)
        // Keyed by category, so when a swipe commits the neighbour's list moves into the main slot
        // instead of being rebuilt.
        for (i in listOfNotNull(state.selected, neighbour)) {
            androidx.compose.runtime.key(i) {
                Box(Modifier.fillMaxSize().graphicsLayer {
                    val off = state.offset
                    translationX = if (i == state.selected) off * size.width else (off + if (off < 0) 1f else -1f) * size.width
                }) {
                    androidx.compose.runtime.CompositionLocalProvider(LocalSlideIn provides if (i == state.selected) slide else incoming) { content(i) }
                }
            }
        }
    }
}

/** MOT-21: a category's rows offset by index × 50 zpx times their stagger. [incoming]: the dragged-in neighbour. */
class SlideIn(private val state: CategoryPagerState, private val incoming: Boolean = false) {
    fun offsetZpx(rowIndex: Int): Float {
        val m = TennisTokens.Motion
        if (incoming) {
            if (!state.neighbourStaggered || !animationsOn()) return 0f
            // Dragging toward the next category (offset < 0) brings it in from the right.
            val dir = if (state.offset < 0f) 1 else if (state.offset > 0f) -1 else state.arrivalDirection
            return dir * rowIndex * m.slideInRowOffsetZpx
        }
        return state.arrivalDirection * rowIndex * m.slideInRowOffsetZpx * state.stagger
    }
}

val LocalSlideIn = compositionLocalOf<SlideIn?> { null }

/** Applies MOT-21 to a row: [visibleIndex] counts from the first row on screen (read at draw time, PRF-30). */
fun Modifier.slideIn(slide: SlideIn?, pxPerZpx: Float, visibleIndex: () -> Int): Modifier =
    if (slide == null) this else this.graphicsLayer { translationX = slide.offsetZpx(visibleIndex().coerceIn(0, MAX_ROWS)) * pxPerZpx }

private const val MAX_ROWS = 20

/**
 * MOT-20, MOT-47: category swipes, decided from each touch's first movement. Watching on the first pass,
 * before the list inside, means a mostly-horizontal drag switches categories even while the list
 * is still coasting from a vertical fling (the touch stops the coast; Chris's v0.5.16 report).
 * A mostly-vertical first movement is left to the list.
 */
private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.categorySwipes(state: CategoryPagerState) {
    awaitEachGesture {
        val pass = androidx.compose.ui.input.pointer.PointerEventPass.Initial
        val down = awaitFirstDown(requireUnconsumed = false, pass = pass)
        val slop = viewConfiguration.touchSlop
        var total = androidx.compose.ui.geometry.Offset.Zero
        // Decide the direction once the finger has moved past the slop.
        while (true) {
            val e = awaitPointerEvent(pass)
            val c = e.changes.firstOrNull { it.id == down.id } ?: return@awaitEachGesture
            if (!c.pressed) return@awaitEachGesture
            total = c.position - down.position
            if (total.getDistance() > slop) {
                if (abs(total.x) <= abs(total.y)) return@awaitEachGesture
                c.consume()
                break
            }
        }
        val w = size.width.toFloat()
        val tracker = androidx.compose.ui.input.pointer.util.VelocityTracker()
        tracker.addPosition(down.uptimeMillis, down.position)
        // Start from the movement beyond the slop, so the content doesn't jump.
        state.drag((total.x - kotlin.math.sign(total.x) * slop) / w)
        while (true) {
            val e = awaitPointerEvent(pass)
            val c = e.changes.firstOrNull { it.id == down.id }
            if (c == null) { state.release(0f, 0f); return@awaitEachGesture }
            tracker.addPosition(c.uptimeMillis, c.position)
            if (!c.pressed) {
                c.consume()
                val vel = tracker.calculateVelocity().x
                state.release(vel / w, vel / density)
                return@awaitEachGesture
            }
            val dx = c.position.x - c.previousPosition.x
            c.consume()
            if (dx != 0f) state.drag(dx / w)
        }
    }
}
