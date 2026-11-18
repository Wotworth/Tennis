package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pinch
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Chris, 18 Nov: tapping a bounce on the sample session's court tab must open that shot. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-port-420dpi")
class CourtTapTest {
    @get:Rule val rule = createComposeRule()

    @Test fun tappingABounceOpensItsShot() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val nav = Navigator(Screen.Vision(VisionStore.SAMPLE_ID, 1))
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        val map = rule.onNodeWithTag("courtMap")
        val size = map.fetchSemanticsNode().size
        // the bounces cover the court: single taps over a grid (spaced in time, so none is a
        // double-tap) must land on one within a few tries
        var opened = false
        loop@ for (gy in 2..8) for (gx in 2..6) {
            map.performTouchInput { click(Offset(size.width * gx / 8f, size.height * gy / 10f)) }
            rule.mainClock.advanceTimeBy(600)
            rule.waitForIdle()
            if (nav.current is Screen.VisionShot) { opened = true; break@loop }
        }
        assertTrue("no tap on the court map opened a shot", opened)
    }

    /** A real finger moves a few pixels during a tap; zoomed in, that must still be a tap, not a pan. */
    @Test fun zoomedInAFingerTapStillOpensAShot() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val nav = Navigator(Screen.Vision(VisionStore.SAMPLE_ID, 1))
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        val map = rule.onNodeWithTag("courtMap")
        val size = map.fetchSemanticsNode().size
        map.performTouchInput {
            pinch(center - Offset(20f, 0f), center - Offset(60f, 0f), center + Offset(20f, 0f), center + Offset(60f, 0f))
        }
        rule.waitForIdle()
        // tap the first bounce where it is drawn now (pan it into view first if the pinch moved it out)
        fun dot(): Offset {
            val p = map.fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsProperties.StateDescription].split(" ")
            return Offset(p[5].toFloat(), p[6].toFloat())
        }
        var tries = 0
        while ((dot().x !in 20f..size.width - 20f || dot().y !in 20f..size.height - 20f) && tries++ < 8) {
            val d = dot()
            val to = Offset(d.x.coerceIn(60f, size.width - 60f), d.y.coerceIn(60f, size.height - 60f))
            map.performTouchInput { down(center); moveBy((to - d) / 2f); moveBy((to - d) / 2f); up() }
            rule.mainClock.advanceTimeBy(600);  rule.waitForIdle()
        }
        map.performTouchInput {
            down(dot())
            moveBy(Offset(3f, 2f));  moveBy(Offset(-1f, 2f))
            up()
        }
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
        val opened = nav.current is Screen.VisionShot
        assertTrue("zoomed in, no finger tap on the court map opened a shot", opened)
    }
}
