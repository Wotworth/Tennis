package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pinch
import androidx.compose.ui.test.swipe
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Chris, 17 Nov: pinch to zoom the court map; a pinch must not turn the page to another tab. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-port-420dpi")
class CourtZoomTest {
    @get:Rule val rule = createComposeRule()

    @Test fun pinchZoomsTheCourtAndStaysOnIt() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val nav = Navigator(Screen.Vision(VisionStore.SAMPLE_ID, 1))
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        val map = rule.onNodeWithTag("courtMap")
        fun state() = map.fetchSemanticsNode().config[SemanticsProperties.StateDescription].split(" ")   // zoom z pan x dot x y
        fun zoom() = state()[1].toFloat()
        fun panX() = state()[3].toFloat()
        assertEquals(1f, zoom(), 1e-3f)
        map.performTouchInput {
            pinch(center - Offset(20f, 0f), center - Offset(200f, 0f), center + Offset(20f, 0f), center + Offset(200f, 0f))
        }
        rule.waitForIdle()
        assertTrue("zoom ${zoom()}", zoom() > 2f)
        assertEquals(Screen.Vision(VisionStore.SAMPLE_ID, 1), nav.current)
        // zoomed in, one finger pans the map (Chris, 17 Nov) and doesn't turn the page
        val before = panX()
        map.performTouchInput { swipe(center, center + Offset(-250f, 0f), 400) }
        rule.waitForIdle()
        assertTrue("pan ${panX()} from $before", panX() < before - 100f)
        assertEquals(Screen.Vision(VisionStore.SAMPLE_ID, 1), nav.current)
    }
}
