// Copied from the Zune player (Wotworth/zune ui/components/Press.kt at f2d9237), package renamed; changes noted below. (VIS, section 3)
package io.github.wotworth.tennis.ui.components

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.input.pointer.AwaitPointerEventScope
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics

/**
 * NAV-01: tap and long-press detection that a real finger can't lose.
 *
 * Compose's clickable gives up when a list behind it takes the touch, and a list takes every new
 * touch while it is still moving (coasting, or springing back from an overscroll). The press then
 * shows but the click never comes. This detector ignores whether a list used the touch: a release
 * counts as a tap whenever the finger stayed within touch slop of where it went down, however long
 * it was held (short of a long press). Moving further than the slop is a scroll or a swipe, never
 * a tap. Items see the touch before the lists and panels around them, and an item that takes a
 * tap marks the release as used, so an enclosing press (a menu's dismiss area) doesn't also fire.
 */
fun Modifier.zunePress(onLongClick: (() -> Unit)?, onClick: () -> Unit): Modifier = composed {
    val click by rememberUpdatedState(onClick)
    val long by rememberUpdatedState(onLongClick)
    val hasLong = onLongClick != null
    // Where this item is on screen right now: finger movement is measured on the screen, because
    // the item itself can move under a still finger (a list springing back or coasting).
    val placed = androidx.compose.runtime.remember { arrayOfNulls<androidx.compose.ui.layout.LayoutCoordinates>(1) }
    val toScreen: (androidx.compose.ui.geometry.Offset) -> androidx.compose.ui.geometry.Offset = { p ->
        placed[0]?.takeIf { it.isAttached }?.localToRoot(p) ?: p
    }
    this
        .then(androidx.compose.ui.Modifier.onPlaced { placed[0] = it })
        .semantics(mergeDescendants = true) {
            role = Role.Button
            onClick { click(); true }
            if (hasLong) onLongClick { long?.invoke(); true }
        }
        .pointerInput(Unit) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                val start = fingerOnScreen(currentEvent, down, toScreen)
                val slop = viewConfiguration.touchSlop
                val longPress = long
                val outcome = if (longPress != null) {
                    withTimeoutOrNull(viewConfiguration.longPressTimeoutMillis) { awaitRelease(down, start, slop, toScreen) } ?: Outcome.Held
                } else awaitRelease(down, start, slop, toScreen)
                when (outcome) {
                    is Outcome.Up -> { outcome.change.consume(); click() }
                    Outcome.Held -> {
                        long?.invoke()
                        // The release after a long press is not a tap.
                        val end = awaitRelease(down, start, Float.MAX_VALUE, toScreen)
                        if (end is Outcome.Up) end.change.consume()
                    }
                    Outcome.Cancelled -> Unit
                }
            }
        }
}

private sealed interface Outcome {
    class Up(val change: PointerInputChange) : Outcome
    data object Held : Outcome
    data object Cancelled : Outcome
}

/** Waits for the finger to lift; cancelled if it moves beyond [slop] or a second finger takes over. */
private suspend fun AwaitPointerEventScope.awaitRelease(
    down: PointerInputChange,
    start: androidx.compose.ui.geometry.Offset,
    slop: Float,
    toScreen: (androidx.compose.ui.geometry.Offset) -> androidx.compose.ui.geometry.Offset,
): Outcome {
    while (true) {
        val event = awaitPointerEvent()
        val c = event.changes.firstOrNull { it.id == down.id } ?: return Outcome.Cancelled
        if ((fingerOnScreen(event, c, toScreen) - start).getDistance() > slop) return Outcome.Cancelled
        // A release already used by an item inside this one is that item's tap.
        if (!c.pressed) return if (c.isConsumed) Outcome.Cancelled else Outcome.Up(c)
    }
}

/**
 * Where the finger is on the physical screen: the touch's raw position when there's one finger,
 * which no moving list or tilting parent can distort; otherwise mapped from the item.
 */
private fun fingerOnScreen(
    event: androidx.compose.ui.input.pointer.PointerEvent,
    change: PointerInputChange,
    toScreen: (androidx.compose.ui.geometry.Offset) -> androidx.compose.ui.geometry.Offset,
): androidx.compose.ui.geometry.Offset {
    val m = event.motionEvent
    return if (m != null && m.pointerCount == 1) androidx.compose.ui.geometry.Offset(m.rawX, m.rawY) else toScreen(change.position)
}
