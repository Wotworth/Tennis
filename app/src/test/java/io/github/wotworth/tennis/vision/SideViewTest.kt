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
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import io.github.wotworth.tennis.ui.screens.curveStat
import io.github.wotworth.tennis.ui.screens.spinEffectStat
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

    @Test fun aTapStretchesTheHeightsAndOnlyTheChipSaysSo() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val v = app.vision.session(VisionStore.SAMPLE_ID)!!
        VisionDefaults.sideStretched = false;  VisionDefaults.shotView = "side";  app.prefs.chooseShotView("side")
        try {
            CanvasText.record = true; CanvasText.seen.clear()
            rule.setContent { AppRoot(app, Navigator(Screen.VisionShot(v.id, 25, 29))) }
            rule.waitForIdle()
            val view = rule.onNodeWithTag("sideView")
            fun state() = view.fetchSemanticsNode().config[SemanticsProperties.StateDescription]
            assertEquals("true proportion", state())
            val low = view.fetchSemanticsNode().size.height
            assertTrue("labels drawn: ${CanvasText.seen}", CanvasText.seen.containsAll(listOf("baseline", "net", "no spin", "1:1")))
            assertTrue(CanvasText.seen.none { it.contains("stretched") || it.contains("ft") })
            // Chris, 20 Nov: no sentences on the card: no caption, no legend, never "brought it down"
            rule.onAllNodesWithText("tap", substring = true).assertCountEquals(0)
            rule.onAllNodesWithText("brought", substring = true).assertCountEquals(0)
            rule.onAllNodesWithText("dashed", substring = true).assertCountEquals(0)
            // the title is the shot's type; the spin's effect is the first tile
            rule.onNodeWithText("backhand").assertExists()
            rule.onNodeWithText("5.7 ft").assertExists()
            rule.onNodeWithText("longer from slice").assertExists()

            CanvasText.seen.clear()
            view.performTouchInput { click() }
            rule.waitForIdle()
            assertEquals("heights stretched", state())
            assertTrue("the chip: ${CanvasText.seen}", CanvasText.seen.contains("×3"))
            assertTrue("the picture grew from $low to ${view.fetchSemanticsNode().size.height}", view.fetchSemanticsNode().size.height > 1.5 * low)

            view.performTouchInput { click() }
            rule.waitForIdle()
            assertEquals("true proportion", state())
        } finally {
            CanvasText.record = false; VisionDefaults.sideStretched = false
        }
    }

    @Test fun theTopViewShowsTheCurveAndTheChoiceIsRemembered() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val v = app.vision.session(VisionStore.SAMPLE_ID)!!
        VisionDefaults.shotView = "side";  app.prefs.chooseShotView("side")
        val curved = v.shots.first { it.isServe && it.spinCurve != null && kotlin.math.abs(it.spinCurve!!) * Units.FT_PER_M >= 0.5 }
        try {
            CanvasText.record = true; CanvasText.seen.clear()
            rule.setContent { AppRoot(app, Navigator(Screen.VisionShot(v.id, curved.rally, curved.index))) }
            rule.waitForIdle()
            rule.onNodeWithText("top").performClick()
            rule.waitForIdle()
            rule.onNodeWithTag("topView").assertExists()
            assertEquals("top", app.prefs.shotView)
            assertTrue("labelled: ${CanvasText.seen}", CanvasText.seen.contains("no spin"))
            val c = curveStat(curved)!!
            rule.onNodeWithText(c.first).assertExists()
            rule.onNodeWithText(c.second).assertExists()
            assertTrue(c.second, c.second.matches(Regex("curved (left|right) from (slice|sidespin)")))
        } finally {
            CanvasText.record = false; VisionDefaults.shotView = "side"
        }
    }

    @Test fun theCurveTileHidesUnderHalfAFootAndSaysLeftOrRightAsTheHitterSawIt() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val v = app.vision.session(VisionStore.SAMPLE_ID)!!
        val s = v.shots.first { it.bounce != null }
        assertEquals(null, curveStat(s.copy(spinCurve = null)))
        assertEquals(null, curveStat(s.copy(spinCurve = 0.4 / Units.FT_PER_M)))
        assertEquals("curved left from slice", curveStat(s.copy(isServe = false, spinLabel = "slice", spinCurve = 1.3 / Units.FT_PER_M))!!.second)
        assertEquals("curved right from sidespin", curveStat(s.copy(isServe = false, spinLabel = "topspin", spinCurve = -1.3 / Units.FT_PER_M))!!.second)
        assertEquals("1.3 ft", curveStat(s.copy(isServe = false, spinLabel = "topspin", spinCurve = -1.3 / Units.FT_PER_M))!!.first)
        assertEquals("shorter from topspin", spinEffectStat(s.copy(isServe = false, spinLabel = "topspin", spinEffect = -1.0)).second)
    }
}
