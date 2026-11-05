// Copied from the Zune player (Wotworth/zune ui/theme/ZuneTheme.kt at f2d9237); imported fonts and album color removed.
package io.github.wotworth.tennis.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em

/** The size of one Zune pixel in dp for the current window. */
@Immutable
data class Zpx(val dpPerZpx: Float) {
    operator fun invoke(zpx: Float): Dp = (zpx * dpPerZpx).dp

    companion object {
        fun forWindowWidth(widthDp: Float) = Zpx(widthDp / TennisTokens.ZUNE_SCREEN_WIDTH_ZPX)
    }
}

val LocalZpx = staticCompositionLocalOf { Zpx.forWindowWidth(TennisTokens.ZUNE_SCREEN_WIDTH_ZPX) }

private val families = HashMap<TennisTokens.Weight, FontFamily>()

/** One FontFamily per file, so Light and Semilight never collide on weight 300. */
fun fontFor(weight: TennisTokens.Weight): FontFamily = families.getOrPut(weight) { FontFamily(Font(weight.fontRes)) }

fun toneColor(tone: TennisTokens.Tone): Color = when (tone) {
    TennisTokens.Tone.Primary -> TennisTokens.Colors.primary
    TennisTokens.Tone.Secondary -> TennisTokens.Colors.secondary
}

fun applyCase(text: String, case: TennisTokens.Case): String = when (case) {
    TennisTokens.Case.Lowercase -> text.lowercase()
    TennisTokens.Case.Uppercase -> text.uppercase()
    TennisTokens.Case.AsTagged -> text
}

/** Text style for a type role. Sizes are fixed in dp and ignore the system font scale. */
@Composable
fun textStyleFor(role: TennisTokens.Role): TextStyle {
    val zpx = LocalZpx.current
    val size = with(LocalDensity.current) { zpx(role.sizeZpx).toSp() }
    return TextStyle(
        color = toneColor(role.tone),
        fontFamily = fontFor(role.weight),
        fontSize = size,
        lineHeight = size,
        letterSpacing = role.letterSpacingEm.em,
        platformStyle = PlatformTextStyle(includeFontPadding = false),
        lineHeightStyle = LineHeightStyle(
            alignment = LineHeightStyle.Alignment.Proportional,
            trim = LineHeightStyle.Trim.Both,
        ),
    )
}

/** Root of every screen: black, edge to edge, with the zpx unit provided. */
@Composable
fun TennisTheme(content: @Composable () -> Unit) {
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(TennisTokens.Colors.background),
    ) {
        CompositionLocalProvider(LocalZpx provides Zpx.forWindowWidth(maxWidth.value)) {
            content()
        }
    }
}
