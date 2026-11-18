package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.doubleClick
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

/** Chris, 18 Nov: pinch to zoom a footage test's sample frame to check the ring. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-port-420dpi")
class FrameZoomTest {
    @get:Rule val rule = createComposeRule()

    @Test fun pinchZoomsTheFramePansAndSwipesOnlyWhenNotZoomed() {
        val app = Sample.empty()
        val screen = Screen.FootageTest("iphone-2025-11-10-clay", 2)
        val nav = Navigator(screen)
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        val frame = rule.onNodeWithTag("testFrame")
        fun state(): List<String> {
            val s = frame.fetchSemanticsNode().config[SemanticsProperties.StateDescription]   // "frame i zoom z pan x"
            return s.split(" ")
        }
        fun index() = state()[1].toInt()
        fun zoom() = state()[3].toFloat()
        fun panX() = state()[5].toFloat()
        assertEquals(0, index());  assertEquals(1f, zoom(), 1e-3f)
        // pinch: zooms in, stays on the same frame and tab
        frame.performTouchInput {
            pinch(center - Offset(20f, 0f), center - Offset(200f, 0f), center + Offset(20f, 0f), center + Offset(200f, 0f))
        }
        rule.waitForIdle()
        assertTrue("zoom ${zoom()}", zoom() > 2f)
        assertEquals(0, index());  assertEquals(screen, nav.current)
        // zoomed in, one finger pans and doesn't turn the frame or the tab
        val before = panX()
        frame.performTouchInput { swipe(center, center + Offset(-250f, 0f), 400) }
        rule.waitForIdle()
        assertTrue("pan ${panX()} from $before", panX() < before - 100f)
        assertEquals(0, index());  assertEquals(screen, nav.current)
        // double-tap goes back to the whole frame; then a swipe turns to the next frame
        frame.performTouchInput { doubleClick() }
        rule.waitForIdle()
        assertEquals(1f, zoom(), 1e-3f)
        frame.performTouchInput { swipe(center + Offset(200f, 0f), center + Offset(-200f, 0f), 300) }
        rule.waitForIdle()
        assertEquals(1, index());  assertEquals(1f, zoom(), 1e-3f)
    }
}
