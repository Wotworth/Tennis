// press() and baselineAt() copied from the Zune player (Wotworth/zune ui/components/Basics.kt at f2d9237).
package io.github.wotworth.tennis.ui.components

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import io.github.wotworth.tennis.ui.motion.tilt

/** A tap target with the Windows Phone tilt; no ripple or highlight (VIS-04). */
fun Modifier.press(onLongClick: (() -> Unit)? = null, description: String? = null, tilt: Boolean = true, onClick: () -> Unit): Modifier =
    this
        .then(if (description != null) Modifier.semantics { contentDescription = description } else Modifier)
        .zunePress(onLongClick, onClick)
        // After the click detector, so touch bounds aren't rotated by the tilt.
        .then(if (tilt) Modifier.tilt() else Modifier)

/** Places the text so its first baseline is [y] below the top of the slot. */
fun Modifier.baselineAt(y: Dp): Modifier = this.layout { measurable, constraints ->
    val p = measurable.measure(constraints)
    val top = y.roundToPx() - p[FirstBaseline]
    layout(p.width, maxOf(0, top + p.height)) { p.place(0, top) }
}
