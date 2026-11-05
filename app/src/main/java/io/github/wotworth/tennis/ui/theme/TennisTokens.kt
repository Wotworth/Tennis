package io.github.wotworth.tennis.ui.theme

import androidx.compose.animation.core.Easing
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import io.github.wotworth.tennis.R
import kotlin.math.exp

/**
 * Every tunable size, color, type style and motion value (section 0). Structure and the values
 * marked "Zune" are copied from the Zune player's ZuneTokens.kt (Wotworth/zune at f2d9237);
 * the tennis colors are new (VIS-03, VIS-04).
 *
 * Sizes are in Zune pixels (zpx): 1 zpx = window width in dp / 272, as in the Zune player.
 */
object TennisTokens {

    const val ZUNE_SCREEN_WIDTH_ZPX = 272f

    object Colors {
        var background by mutableStateOf(Color(0xFF000000))
        var primary by mutableStateOf(Color(0xFFFFFFFF))
        var secondary by mutableStateOf(Color(0x99FFFFFF))
        var disabled by mutableStateOf(Color(0x66FFFFFF))
        /** VIS-03: the Zune title gradient recolored: tennis-ball yellow-green to deep green (Q3). */
        var titleGradientStart by mutableStateOf(Color(0xFFC9E23A))
        var titleGradientEnd by mutableStateOf(Color(0xFF2B8A3E))
        /** VIS-04: every tile, one deep green (Q4). */
        var tile by mutableStateOf(Color(0xFF2A7F3E))
        /** Context menus and prompts (Windows Phone's dark chrome color). */
        var panel by mutableStateOf(Color(0xFF1F1F1F))
    }

    /** Each role maps to a specific font file, never to a numeric weight (Zune VIS-11). */
    enum class Weight(val fontRes: Int) {
        Light(R.font.selawik_light),
        Semilight(R.font.selawik_semilight),
        Regular(R.font.selawik_regular),
        Semibold(R.font.selawik_semibold),
        Bold(R.font.selawik_bold),
    }

    enum class Case { Lowercase, Uppercase, AsTagged }

    enum class Tone { Primary, Secondary }

    class Role(sizeZpx: Float, weight: Weight, letterSpacingEm: Float, val case: Case, tone: Tone) {
        var sizeZpx by mutableFloatStateOf(sizeZpx)
        var weight by mutableStateOf(weight)
        var letterSpacingEm by mutableFloatStateOf(letterSpacingEm)
        var tone by mutableStateOf(tone)
    }

    object Type {
        // Zune values.
        val giantHeader = Role(155f, Weight.Semilight, -0.02f, Case.Lowercase, Tone.Secondary)
        val categoryLabel = Role(29f, Weight.Bold, 0f, Case.Uppercase, Tone.Primary)
        val listPrimary = Role(22f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        val listSecondary = Role(13f, Weight.Regular, 0f, Case.AsTagged, Tone.Secondary)
        // VIS-01: the headline number on the hours tile, and the line under it.
        val headlineNumber = Role(72f, Weight.Light, 0f, Case.AsTagged, Tone.Primary)
        val tileLabel = Role(13f, Weight.Regular, 0f, Case.Lowercase, Tone.Primary)
        /** Monospaced-free plain text blocks: the crash log and the Health Connect summary. */
        val log = Role(11f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
    }

    object Layout {
        // Zune values.
        var giantHeaderBaseline by mutableFloatStateOf(62f)
        var giantHeaderLeft by mutableFloatStateOf(-25f)
        var categoryBarLeft by mutableFloatStateOf(9f)
        var categoryBarBaseline by mutableFloatStateOf(98f)
        var pageSideMargin by mutableFloatStateOf(16f)
        var listTop by mutableFloatStateOf(118f)
        var listRowGap by mutableFloatStateOf(14f)
        var listBottomPadding by mutableFloatStateOf(80f)
        var logRowGap by mutableFloatStateOf(12f)
        // New: the app bar's "…" (NAV-08), bottom right.
        var appBarHeight by mutableFloatStateOf(44f)
        var appBarDotsSize by mutableFloatStateOf(36f)
        // VIS-04: tiles.
        var tileGap by mutableFloatStateOf(8f)
        var tilePadding by mutableFloatStateOf(8f)
    }

    object Easings {
        private const val EXPO_POWER = 6.0
        val expoIn6 = Easing { t -> ((exp(EXPO_POWER * t) - 1) / (exp(EXPO_POWER) - 1)).toFloat() }
        val expoOut6 = Easing { t -> 1f - expoIn6.transform(1f - t) }
    }

    /** Zune motion values (its MOT-20 to MOT-22), as tuned on Chris's phone. */
    object Motion {
        var speedMultiplier by mutableFloatStateOf(1f)
        var swipeCommitFraction by mutableFloatStateOf(0.24f)
        var swipeCommitVelocityDpPerS by mutableFloatStateOf(380f)
        var springBackMs by mutableIntStateOf(280)
        var slideInRowOffsetZpx by mutableFloatStateOf(50f)
        var slideInSettleMs by mutableIntStateOf(420)
        var tiltMaxDegrees by mutableFloatStateOf(17.2f)
        var tiltMaxSink by mutableFloatStateOf(0.025f)
        var tiltReleaseDelayMs by mutableIntStateOf(200)
        var tiltReleaseMs by mutableIntStateOf(100)
        var tiltCameraDistance by mutableFloatStateOf(16f)
    }

    /** DET-01: how many days back the Health Connect report can go. */
    object Health {
        var reportMaxDaysBack by mutableIntStateOf(30)
    }
}
