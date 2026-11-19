package io.github.wotworth.tennis.vision

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.screens.Court
import io.github.wotworth.tennis.ui.screens.SideGeometry
import io.github.wotworth.tennis.ui.screens.VisionDefaults
import io.github.wotworth.tennis.ui.theme.TennisTokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

/**
 * Chris, 19 Nov: the shot card's side view was unlabelled and out of proportion. It is now the whole
 * court in true proportion with the baselines, service lines and net marked and labelled; a tap
 * stretches the heights three times, and the picture says so.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-port-420dpi")
class SideViewTest {
    @get:Rule val rule = createComposeRule()

    private fun sample(): VisionSession {
        fun read(n: String) = File("src/main/assets/vision/sample/$n").readText()
        return VisionJson.session("sample", read("session.json"), read("shots.json"), read("rallies.json"), read("trajectories.json"), sample = true)
    }

    @Test fun theCourtIsWholeAndTheBallIsWhereItWasAlongIt() {
        val tok = TennisTokens.Vision
        var checked = 0
        for (s in sample().let { v -> v.shots.map { it to v.trajectory(it.rally, it.index) } }) {
            val (shot, tr) = s
            if (tr == null) continue
            val g = SideGeometry(tr, tok.sideViewMarginM.toDouble(), tok.sideViewMinTopM.toDouble(), tok.sideViewMinAlong.toDouble())
            val name = "shot ${shot.rally}·${shot.index}"
            // the same court for every shot: the net in the middle, the lines at their real distances from it
            assertEquals(listOf("baseline", "service line", "net", "service line", "baseline"), g.marks.map { it.second })
            assertEquals(g.spanM / 2, g.marks[2].first, 1e-9)
            assertEquals(Court.HALF_LENGTH, g.marks[2].first - g.marks[0].first, 1e-9)
            assertEquals(Court.SERVICE, g.marks[3].first - g.marks[2].first, 1e-9)
            // the hitter is on the left
            assertTrue("$name: the contact point is not on the left", g.across(tr.xyz.first()) < g.spanM / 2)
            // heights are never drawn on a larger scale than the distance along the court
            assertTrue(g.along > 0.0 && g.along <= 1.0)
            // the bounce is drawn as far short of the far baseline as the card says
            val bounce = shot.bounce; val depth = shot.depth
            if (bounce != null && depth != null && shot.call != "net") {
                assertEquals("$name: the bounce against the far baseline", depth, g.marks[4].first - g.across(doubleArrayOf(bounce[0], bounce[1], 0.0)), 0.01)
                checked++
            }
        }
        assertTrue("checked $checked bounces", checked > 100)
    }

    @Test fun aTapStretchesTheHeightsAndThePictureSaysSo() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val v = app.vision.session(VisionStore.SAMPLE_ID)!!
        VisionDefaults.sideStretched = false
        try {
            CanvasText.record = true; CanvasText.seen.clear()
            rule.setContent { AppRoot(app, Navigator(Screen.VisionShot(v.id, 29, 1))) }
            rule.waitForIdle()
            val view = rule.onNodeWithTag("sideView")
            fun state() = view.fetchSemanticsNode().config[SemanticsProperties.StateDescription]
            assertEquals("true proportion", state())
            val low = view.fetchSemanticsNode().size.height
            assertTrue("labels drawn: ${CanvasText.seen}", CanvasText.seen.containsAll(listOf("baseline", "service line", "net")))
            assertTrue(CanvasText.seen.none { it.startsWith("heights stretched") })
            rule.onNodeWithText("true proportion · tap to stretch heights ×3").assertExists()

            CanvasText.seen.clear()
            view.performTouchInput { click() }
            rule.waitForIdle()
            assertEquals("heights stretched", state())
            assertTrue("said on the picture: ${CanvasText.seen}", CanvasText.seen.contains("heights stretched ×3"))
            assertTrue("height marks: ${CanvasText.seen}", CanvasText.seen.containsAll(listOf("5 ft", "10 ft")))
            assertTrue("the picture grew from $low to ${view.fetchSemanticsNode().size.height}", view.fetchSemanticsNode().size.height > 1.5 * low)
            rule.onNodeWithText("heights stretched ×3 · tap for true proportion").assertExists()

            view.performTouchInput { click() }
            rule.waitForIdle()
            assertEquals("true proportion", state())
        } finally {
            CanvasText.record = false; VisionDefaults.sideStretched = false
        }
    }
}
