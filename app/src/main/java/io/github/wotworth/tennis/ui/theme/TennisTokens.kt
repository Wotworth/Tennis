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
        /** NAV-08: the application bar (Windows Phone dark theme). */
        var appBar by mutableStateOf(Color(0xFF1F1F1F))
        /**
         * CUE-03 (v0.5, Chris 6 Nov): one colour per stroke on the cues page, from the Windows
         * Phone accent colours, lightened where needed to read on black (unit test: 4.5:1).
         */
        val strokes: Map<String, Color> = mapOf(
            "forehand" to Color(0xFF1BA1E2),   // cyan
            "backhand" to Color(0xFFFA6800),   // orange
            "serve" to Color(0xFFF472D0),      // pink
            "return" to Color(0xFF00ABA9),     // teal
            "volley" to Color(0xFFF0A30A),     // amber
            "footwork" to Color(0xFFB18CFF),   // violet, lightened
            "gameplay" to Color(0xFFA4C400),   // lime
            "mental" to Color(0xFFA0A9B8),     // steel, lightened
        )
        /** Strokes Chris types himself. */
        var strokeOther by mutableStateOf(Color(0xFFC8C8C8))
        fun stroke(heading: String): Color = strokes[heading.trim().lowercase()] ?: strokeOther

        /**
         * TIL-06 (v0.9, Chris 8 Nov): the same stroke colours on the launcher tile, each lightened
         * just enough to read at 3:1 on the tile green (the app's colours read on black, not on
         * green). Unit test checks every one.
         */
        val strokesOnTile: Map<String, Color> = mapOf(
            "forehand" to Color(0xFF92D2F1),
            "backhand" to Color(0xFFFDBD8F),
            "serve" to Color(0xFFF9B3E6),
            "return" to Color(0xFF85D7D6),
            "volley" to Color(0xFFF5C25D),
            "footwork" to Color(0xFFD3BFFF),
            "gameplay" to Color(0xFFBDD547),
            "mental" to Color(0xFFC4CAD3),
        )
        var strokeOtherOnTile by mutableStateOf(Color(0xFFC9C9C9))
        fun strokeOnTile(heading: String): Color = strokesOnTile[heading.trim().lowercase()] ?: strokeOtherOnTile

        /** NAV-07: the Windows Phone dark-theme text box, unfocused. */
        var textBox by mutableStateOf(Color(0xFFBFBFBF))
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
        val tileLabel = Role(13f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        /** Plain text blocks: the crash log. */
        val log = Role(11f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        /** v0.3 title (Chris's option a): Windows Phone pivot. Small all-caps app title, large lowercase page headers. */
        val appTitle = Role(13f, Weight.Semibold, 0.02f, Case.Uppercase, Tone.Primary)
        val pivotHeader = Role(42f, Weight.Light, -0.01f, Case.Lowercase, Tone.Primary)
        /** A form page's header (WP's page title under the app title). */
        val pageHeader = Role(42f, Weight.Light, -0.01f, Case.Lowercase, Tone.Primary)
        val sectionHeader = Role(17f, Weight.Semilight, 0f, Case.Lowercase, Tone.Secondary)
        val body = Role(15f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        val menuItem = Role(22f, Weight.Light, 0f, Case.Lowercase, Tone.Primary)
        val button = Role(15f, Weight.Semibold, 0f, Case.Lowercase, Tone.Primary)
        val input = Role(16f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        val choice = Role(22f, Weight.Light, 0f, Case.AsTagged, Tone.Primary)
        /** NAV-02: the big number on a medium tile, and on a small tile. */
        val tileNumber = Role(40f, Weight.Light, -0.01f, Case.AsTagged, Tone.Primary)
        val tileNumberSmall = Role(22f, Weight.Light, 0f, Case.AsTagged, Tone.Primary)
        val tileText = Role(14f, Weight.Regular, 0f, Case.AsTagged, Tone.Primary)
        val tileTextLarge = Role(20f, Weight.Semilight, 0f, Case.AsTagged, Tone.Primary)
        val tileLabelSmall = Role(9f, Weight.Regular, 0f, Case.Lowercase, Tone.Primary)
        /** CUE-10: a pinned cue on the warmup view, and its heading. */
        val warmupCue = Role(18f, Weight.Semilight, 0f, Case.AsTagged, Tone.Primary)
        /** CUE-03: a stroke's name over its cues, in the stroke's colour. */
        val cueHeading = Role(14f, Weight.Semibold, 0.02f, Case.Lowercase, Tone.Primary)
        /** Cues that aren't pinned, a step smaller. */
        val cueOther = Role(15f, Weight.Regular, 0f, Case.AsTagged, Tone.Secondary)
        /** DET-30: the prompt's question. */
        val promptTitle = Role(26f, Weight.Light, 0f, Case.AsTagged, Tone.Primary)
        /** The shop order card (STR-20): the values, and the labels over them. */
        /** RAC-04: racquet names in the switcher. */
        val racquetName = Role(22f, Weight.Semilight, 0f, Case.AsTagged, Tone.Primary)
        val orderValue = Role(30f, Weight.Light, 0f, Case.AsTagged, Tone.Primary)
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
        // VIS-04, NAV-02: tiles. Widths in zpx; the page is 240 zpx wide inside its margins.
        var tileGap by mutableFloatStateOf(8f)
        var tilePadding by mutableFloatStateOf(8f)
        var tileMedium by mutableFloatStateOf(116f)
        var tileSmall by mutableFloatStateOf(54f)
        var tileWideHeight by mutableFloatStateOf(116f)
        // The pivot (v0.3 title): app title and header baselines, and where the page content starts.
        var appTitleBaseline by mutableFloatStateOf(20f)
        var pivotHeaderLeft by mutableFloatStateOf(12f)
        var pivotHeaderBaseline by mutableFloatStateOf(66f)
        var pivotContentTop by mutableFloatStateOf(84f)
        // App bar buttons (NAV-08).
        var appBarButton by mutableFloatStateOf(32f)
        var ringStroke by mutableFloatStateOf(1.5f)
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

    /** SES-01: the session page's starting length and presets (minutes). */
    object Sessions {
        var defaultMinutes by mutableIntStateOf(90)
        val presets = listOf(60, 90, 120)
    }

    /** NAV-02: how dark the package photo behind the setup tile is made, for white text. */
    object Photos {
        var scrim by mutableFloatStateOf(0.55f)
    }

    /** Section 9: chart height (zpx) and how many string jobs the feel chart draws. */
    object Stats {
        var chartHeight by mutableFloatStateOf(130f)
        var jobsInChart by mutableIntStateOf(4)
    }

    /** CUE-10: spacing on the cues page (zpx). */
    object Cues {
        var betweenCues by mutableFloatStateOf(8f)
        var betweenStrokes by mutableFloatStateOf(18f)
        var barWidth by mutableFloatStateOf(3f)
        var barGap by mutableFloatStateOf(9f)
    }

    object Lists {
        /** NAV-02: restrings listed under the tiles. */
        var recentRestrings by mutableIntStateOf(5)
    }

    /** DET-01: how many days back the Health Connect report can go. */
    object Health {
        var reportMaxDaysBack by mutableIntStateOf(365)
    }
}
