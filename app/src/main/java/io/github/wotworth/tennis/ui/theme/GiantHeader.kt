// Copied from the Zune player (Wotworth/zune ui/theme/GiantHeader.kt at f2d9237): the zoom-transition
// visibility flag is removed and the gradient colors come from TennisTokens (VIS-03).
package io.github.wotworth.tennis.ui.theme

import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints

/**
 * The giant lowercase screen title: its left edge starts off screen, the word runs off the right
 * edge, and it is filled with the title gradient. Place it directly below the status-bar inset.
 */
@Composable
fun GiantHeader(text: String, modifier: Modifier = Modifier) {
    val role = TennisTokens.Type.giantHeader
    val zpx = LocalZpx.current
    BasicText(
        text = applyCase(text, role.case),
        // Opaque, so the gradient shows at full strength.
        style = textStyleFor(role).copy(color = TennisTokens.Colors.primary),
        maxLines = 1,
        softWrap = false,
        overflow = TextOverflow.Visible,
        modifier = modifier
            .clipToBounds()
            .titleGradient()
            .layout { measurable, constraints ->
                val placeable = measurable.measure(Constraints())
                val baseline = placeable[FirstBaseline]
                val baselineY = zpx(TennisTokens.Layout.giantHeaderBaseline).roundToPx()
                val left = zpx(TennisTokens.Layout.giantHeaderLeft).roundToPx()
                val height = baselineY + (placeable.height - baseline)
                layout(constraints.maxWidth, height) {
                    placeable.place(left, baselineY - baseline)
                }
            },
    )
}

/** Plain text in a type role, colored and cased by the role. */
@Composable
fun TennisText(text: String, role: TennisTokens.Role, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE) {
    BasicText(
        text = applyCase(text, role.case),
        style = textStyleFor(role),
        maxLines = maxLines,
        overflow = TextOverflow.Clip,
        modifier = modifier,
    )
}

/** VIS-03: the title gradient, left to right across the space this modifier is laid out in. */
fun Modifier.titleGradient(): Modifier = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(
            Brush.horizontalGradient(
                listOf(TennisTokens.Colors.titleGradientStart, TennisTokens.Colors.titleGradientEnd),
                startX = 0f, endX = size.width,
            ),
            blendMode = BlendMode.SrcAtop,
        )
    }

