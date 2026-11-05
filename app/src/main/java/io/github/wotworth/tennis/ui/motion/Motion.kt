// Copied from the Zune player (Wotworth/zune ui/motion/Motion.kt at f2d9237), package renamed; changes noted below. (VIS, section 3)
package io.github.wotworth.tennis.ui.motion

import android.animation.ValueAnimator
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.TweenSpec
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntSize
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Screenshot tests set this so endless motion (MOT-31, MOT-32) doesn't stop the UI from settling. */
@Volatile var stillForScreenshots = false

/** MOT-46, NFR-32: false when the system "Remove animations" setting is on. */
fun animationsOn(): Boolean = !stillForScreenshots && ValueAnimator.areAnimatorsEnabled()

/** A motion duration after the tuning panel's speed multiplier (MOT-40) and MOT-46. */
fun dur(ms: Int): Int = if (!animationsOn()) 0 else (ms / TennisTokens.Motion.speedMultiplier).roundToInt()

fun <T> zTween(ms: Int, easing: Easing, delayMs: Int = 0): TweenSpec<T> = tween(dur(ms), dur(delayMs), easing)

/**
 * MOT-22 (Windows Phone TiltEffect): on touch the item tilts toward the finger, up to
 * [TennisTokens.Motion.tiltMaxDegrees] at its corners, and sinks by up to
 * [TennisTokens.Motion.tiltMaxSink] at its center, tracking the finger. On release it returns flat
 * after a short delay. Observes touches without consuming them.
 */
fun Modifier.tilt(): Modifier = composed {
    var rx by remember { mutableFloatStateOf(0f) }
    var ry by remember { mutableFloatStateOf(0f) }
    var sink by remember { mutableFloatStateOf(0f) }
    this
        .pointerInput(Unit) {
            coroutineScope {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                    fun apply(p: Offset, size: IntSize) {
                        if (!animationsOn()) return
                        val nx = ((p.x / size.width) * 2 - 1).coerceIn(-1f, 1f)
                        val ny = ((p.y / size.height) * 2 - 1).coerceIn(-1f, 1f)
                        val m = TennisTokens.Motion
                        // Pressing the right edge pushes it away: the item turns about its vertical axis.
                        ry = nx * m.tiltMaxDegrees
                        rx = -ny * m.tiltMaxDegrees
                        sink = m.tiltMaxSink * (1 - maxOf(kotlin.math.abs(nx), kotlin.math.abs(ny)))
                    }
                    apply(down.position, size)
                    while (true) {
                        val e = awaitPointerEvent(PointerEventPass.Initial)
                        val c = e.changes.firstOrNull { it.id == down.id } ?: break
                        if (!c.pressed) break
                        apply(c.position, size)
                    }
                    val m = TennisTokens.Motion
                    launch {
                        delay(dur(m.tiltReleaseDelayMs).toLong())
                        val steps = (dur(m.tiltReleaseMs) / FRAME_MS).coerceAtLeast(1)
                        val (x0, y0, s0) = Triple(rx, ry, sink)
                        for (i in 1..steps) {
                            val f = 1f - i.toFloat() / steps
                            rx = x0 * f; ry = y0 * f; sink = s0 * f
                            delay(FRAME_MS.toLong())
                        }
                        rx = 0f; ry = 0f; sink = 0f
                    }
                }
            }
        }
        .graphicsLayer {
            rotationX = rx
            rotationY = ry
            val s = 1f - sink
            scaleX = s; scaleY = s
            cameraDistance = TennisTokens.Motion.tiltCameraDistance * density
        }
}

private const val FRAME_MS = 16
