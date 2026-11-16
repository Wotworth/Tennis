package io.github.wotworth.tennis.screenshots

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.Overlays
import io.github.wotworth.tennis.ui.screens.CourtVariantA
import io.github.wotworth.tennis.ui.screens.CourtVariantB
import io.github.wotworth.tennis.ui.screens.CourtVariantC
import io.github.wotworth.tennis.ui.screens.ShotVariantA
import io.github.wotworth.tennis.ui.screens.ShotVariantB
import io.github.wotworth.tennis.ui.screens.TrendsVariantA
import io.github.wotworth.tennis.ui.screens.TrendsVariantB
import io.github.wotworth.tennis.ui.theme.TennisTheme
import io.github.wotworth.tennis.vision.VisionStore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Design v2 variations (Chris, 16 Nov), on the synthetic sample session at 1080 x 2340, for Chris
 * to pick from. Images land in app/build/outputs/roborazzi/v2/ and are copied to docs/preview/v2/.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = ScreenshotTest.W360)
class DesignV2Screenshots {
    init { io.github.wotworth.tennis.ui.motion.stillForScreenshots = true }

    private fun app(): TennisApp = Sample.fill().also { it.prefs.answerVisionSampleIdentity("Player A") }
    private fun shot(name: String, content: @Composable (TennisApp) -> Unit) {
        val a = app()
        captureRoboImage("build/outputs/roborazzi/v2/$name.png") {
            TennisTheme {
                CompositionLocalProvider(LocalApp provides a, LocalNav provides Navigator(), LocalOverlays provides Overlays()) { content(a) }
            }
        }
    }
    private fun TennisApp.session() = vision.session(VisionStore.SAMPLE_ID)!!
    private fun TennisApp.answer() = prefs.visionSampleIdentity

    @Test fun courtA() = shot("court-A-strips-everyone-speed") { CourtVariantA(it.session(), it.answer(), "all", "speed", "all") }
    @Test fun courtB() = shot("court-B-filterbar-everyone-forehands-speed") { CourtVariantB(it.session(), it.answer(), "forehand", "speed", "all") }
    @Test fun courtBOpen() = shot("court-B2-filterbar-panel-open") { CourtVariantB(it.session(), it.answer(), "forehand", "speed", "all", open = true) }
    @Test fun courtBSpin() = shot("court-B3-filterbar-everyone-spin") { CourtVariantB(it.session(), it.answer(), "all", "spin", "all") }
    @Test fun courtC() = shot("court-C-dot-size-everyone-speed") { CourtVariantC(it.session(), it.answer(), "all", "speed", "all") }
    @Test fun shotA() = shot("shot-A-two-column-grid") { a -> a.session().let { v -> ShotVariantA(v, v.shot(3, 2)!!, a.answer()) } }
    @Test fun shotAOpp() = shot("shot-A2-two-column-grid-opponent-shot") { a -> a.session().let { v -> ShotVariantA(v, v.shot(3, 3)!!, a.answer()) } }
    @Test fun shotB() = shot("shot-B-headline-and-groups") { a -> a.session().let { v -> ShotVariantB(v, v.shot(3, 2)!!, a.answer()) } }
    @Test fun trendsA() = shot("trends-A-selectors") { a -> TrendsVariantA(racquetName(a)) }
    @Test fun trendsAOpen() = shot("trends-A2-selectors-panel-open") { a -> TrendsVariantA(racquetName(a), open = true) }
    @Test fun trendsB() = shot("trends-B-filterbar-and-strip") { a -> TrendsVariantB(racquetName(a)) }

    private fun racquetName(a: TennisApp): String? = kotlinx.coroutines.runBlocking { a.repo.dao.racquetsNow() }.firstOrNull { !it.retired }?.name
}
