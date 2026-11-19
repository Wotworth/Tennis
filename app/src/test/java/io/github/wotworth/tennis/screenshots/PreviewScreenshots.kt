package io.github.wotworth.tennis.screenshots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.NumberTile
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.screens.LIBRARY
import io.github.wotworth.tennis.ui.screens.SESSIONS
import io.github.wotworth.tennis.ui.screens.VisionDefaults
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTheme
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.VisionStore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * The Tennis Vision design preview (Chris, 15 Nov): the real screens, on the synthetic 90-minute
 * session bundled as the sample, at the Galaxy S25's 1080 x 2340. Images land in
 * app/build/outputs/roborazzi/preview/. The launcher tile states are a mockup made of the tennis
 * app's own tile parts (the launcher draws them itself).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = ScreenshotTest.W360)
class PreviewScreenshots {
    init { io.github.wotworth.tennis.ui.motion.stillForScreenshots = true }

    private val id = VisionStore.SAMPLE_ID
    private fun shot(name: String, content: @Composable () -> Unit) =
        captureRoboImage("build/outputs/roborazzi/preview/$name.png") { content() }
    private fun screen(name: String, s: Screen, app: TennisApp = Sample.fill()) = shot(name) { AppRoot(app, Navigator(s)) }
    private fun identified(): TennisApp = Sample.fill().also { it.prefs.answerVisionSampleIdentity("Player A") }

    @Test fun p01SessionsList() = screen("01-sessions-list", Screen.Hub(SESSIONS))
    @Test fun p02SummaryBefore() = screen("02a-summary-before-identified", Screen.Vision(id, 0))
    @Test fun p02SummaryAfter() = screen("02b-summary-after-identified", Screen.Vision(id, 0), identified())
    @Test @Config(qualifiers = "w360dp-h1700dp-port-xxhdpi") fun p02SummaryWhole() = screen("02c-summary-whole-page", Screen.Vision(id, 0), identified())
    @Test fun p03CourtSpeed() { VisionDefaults.courtType = "forehand"; VisionDefaults.courtColour = "speed"; screen("03a-court-map-forehands-speed", Screen.Vision(id, 1), identified()) }
    @Test fun p03CourtSpin() { VisionDefaults.courtType = "forehand"; VisionDefaults.courtColour = "spin"; screen("03b-court-map-forehands-spin", Screen.Vision(id, 1), identified()) }
    @Test fun p03CourtServes() { VisionDefaults.courtType = "serve"; VisionDefaults.courtColour = "speed"; screen("03c-court-map-serves-speed", Screen.Vision(id, 1), identified()) }
    @Test fun p04ShotCard() { val a = identified(); val s = a.vision.session(id)!!.shots.first { it.hitter == "Player A" && !it.isServe && it.bounce != null }
        screen("04-shot-card", Screen.VisionShot(id, s.rally, s.index), a) }
    // Chris, 19 Nov: the side view is the whole court in true proportion; a tap stretches the heights three times
    @Test fun p04ShotCardServe() { VisionDefaults.sideStretched = false; screen("04b-shot-card-serve-true-proportion", Screen.VisionShot(id, 29, 1), identified()) }
    @Test fun p04ShotCardServeStretched() {
        VisionDefaults.sideStretched = true
        try { screen("04c-shot-card-serve-heights-stretched", Screen.VisionShot(id, 29, 1), identified()) } finally { VisionDefaults.sideStretched = false }
    }
    @Test fun p05Rallies() = screen("05-3d-rallies", Screen.Vision(id, 2), identified())
    @Test fun p06Replay() = screen("06-3d-rally-replay", Screen.VisionRally(id, 1), identified())
    @Test fun p07Health() = screen("07-health", Screen.Vision(id, 3), identified())
    @Test fun p07Trends() = screen("07b-session-trends", Screen.Vision(id, 4), identified())
    @Test fun p08Trends() = screen("08-trends", Screen.VisionTrends, identified())
    // Footage tests (Chris, 17 Nov): the one-camera iPhone runs bundled in assets/vision/tests/
    @Test fun p09WhichOne() = screen("09-which-one-is-you", Screen.VisionIdentity(id))
    @Test fun p10Courts() = screen("10a-courts-list", Screen.Hub(LIBRARY))
    @Test fun p10AddCourt() = screen("10b-add-court", Screen.CourtEdit())
    @Test fun p13ClaySummary() = screen("13a-clay-test-summary", Screen.FootageTest("iphone-2025-11-10-clay", 0))
    @Test fun p13ClayBall() = screen("13b-clay-test-ball", Screen.FootageTest("iphone-2025-11-10-clay", 2))
    @Test fun p13ClayBounces() = screen("13c-clay-test-bounces", Screen.FootageTest("iphone-2025-11-10-clay", 3))
    @Test fun p13ClayRallies() = screen("13d-clay-test-rallies", Screen.FootageTest("iphone-2025-11-10-clay", 4))

    /** MOCKUP: the launcher tile's states, highest priority first (TV-APP-07). */
    @Test fun p11LauncherTile() = shot("11-launcher-tile-states-mockup") {
        TennisTheme {
            val zpx = LocalZpx.current
            val l = TennisTokens.Layout
            val w = zpx(l.tileMedium * 2 + l.tileGap); val h = zpx(l.tileMedium * 0.8f)
            Column(Modifier.fillMaxSize().background(TennisTokens.Colors.background).padding(zpx(16f))) {
                TennisText("launcher tile states, first wins (mockup)", TennisTokens.Type.listSecondary)
                Spacer(Modifier.height(zpx(4f)))
                @Composable fun state(n: String, caption: String, content: @Composable () -> Unit) {
                    TennisText("$n  $caption", TennisTokens.Type.listSecondary)
                    Spacer(Modifier.height(zpx(2f)))
                    content()
                    Spacer(Modifier.height(zpx(5f)))
                }
                state("1", "found a session: tap for yes / no") {
                    Tile("tennis", w, h) { TileLines(listOf("Tennis?", "Today 5:10–6:35 PM")) }
                }
                state("2", "a vision session has a question") {
                    Tile("tennis", w, h) { TileLines(listOf("1 question", "which one is you?")) }
                }
                state("3", "new vision session, until opened") {
                    Tile("tennis", w, h) { TileLines(listOf("214 shots", "serve 106 mph · forehand 64 mph")) }
                }
                state("4", "otherwise: your cues") {
                    Tile("tennis", w, h) {
                        Column(Modifier.align(Alignment.TopStart)) {
                            TennisText("forehand", TennisTokens.Type.cueHeading)
                            TennisText("Keep the racket face flat on the backswing.", TennisTokens.Type.tileTextLarge)
                        }
                    }
                }
                state("5", "tile off, or no cue fits") {
                    Row { io.github.wotworth.tennis.ui.components.GlyphTile("tennis", io.github.wotworth.tennis.R.drawable.glyph_racket, h) }
                }
            }
        }
    }
}
