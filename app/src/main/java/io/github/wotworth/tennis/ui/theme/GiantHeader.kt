// TennisText and titleGradient copied from the Zune player (Wotworth/zune ui/theme/GiantHeader.kt at f2d9237).
// The clipped giant title itself was removed in PH-1 (v0.3 title: Windows Phone pivot instead).
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

