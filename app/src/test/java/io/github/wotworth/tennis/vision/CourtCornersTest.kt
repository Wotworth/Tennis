package io.github.wotworth.tennis.vision

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pinch
import androidx.compose.ui.test.swipe
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.screens.SESSIONS
import io.github.wotworth.tennis.ui.screens.cornerPrompt
import io.github.wotworth.tennis.ui.screens.placeCorner
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * "Court corners" (Chris, 19 Nov; TV-CAL-21, 22): the fallback when the PC's court-line fit for a
 * camera is doubtful. The four corners of the doubles court are tapped on the camera's picture,
 * or the drawn lines are accepted; the answer waits in the outbox exactly as the Worker takes it.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h891dp-port-420dpi")
class CourtCornersTest {
    @get:Rule val rule = createComposeRule()

    /** The sample court's real doubles corners in its picture (vision/tools/previewCorners.m prints them). */
    private val trueCorners = listOf(Offset(724.2f, 963.7f), Offset(666.6f, 557.6f), Offset(1479.6f, 486.5f), Offset(1822.7f, 562.6f))

    private fun sampleApp() = Sample.empty().also { it.prefs.chooseVisionSample(true) }

    @Test fun theSampleCheckReadsAsOneCameraWithItsFittedLines() {
        val app = sampleApp()
        val c = app.vision.cornerChecks(true).single()
        assertEquals(1, c.cam);  assertEquals(1920, c.width);  assertEquals(1080, c.height)
        assertEquals("lines", c.reason)
        assertTrue("support ${c.support}", c.support > 0.0 && c.support < 0.35)        // doubtful: under the PC's alert level
        assertTrue("${c.lines.size} lines", c.lines.size >= 9)
        c.lines.flatten().forEach { p -> assertTrue("$p", p.x in 0f..1920f && p.y in 0f..1080f) }
        val b = app.vision.cornerImage(c)!!
        assertEquals(1920, b.width);  assertEquals(1080, b.height)
        // every real corner is in the picture, and none of the drawn (misplaced) lines ends on all of them
        trueCorners.forEach { p -> assertTrue("$p", p.x in 0f..1920f && p.y in 0f..1080f) }
        assertTrue(cornerPrompt(c).contains("tap the four corners of the doubles court"))
        assertTrue(cornerPrompt(c.copy(reason = "taps")).contains("did not make a court"))
        assertTrue(app.vision.cornerChecks(false).isEmpty())                            // nothing without the sample (no cloud yet)
    }

    @Test fun aTouchMapsToThePictureThroughZoomAndPanAndBack() {
        val box = Size(1080f, 607.5f)
        val p = CornerGeometry.toPicture(Offset(540f, 303.75f), box, 1f, Offset.Zero, 1920, 1080)
        assertEquals(960f, p.x, 0.01f);  assertEquals(540f, p.y, 0.01f)
        // zoomed 4 times about the top-left and shifted: the same picture point comes back
        val zoom = 4f;  val pan = Offset(-1500f, -900f)
        val q = CornerGeometry.toPicture(Offset(300f, 200f), box, zoom, pan, 1920, 1080)
        val back = CornerGeometry.toBox(q, box, zoom, pan, 1920, 1080)
        assertEquals(300f, back.x, 0.01f);  assertEquals(200f, back.y, 0.01f)
        assertEquals((300f + 1500f) / 4f / 1080f * 1920f, q.x, 0.01f)
        // a touch past the edge stays inside the picture
        val edge = CornerGeometry.toPicture(Offset(-20f, 9999f), box, 1f, Offset.Zero, 1920, 1080)
        assertEquals(0f, edge.x, 0f);  assertEquals(1080f, edge.y, 0f)
        // a pinch keeps the point under the fingers and never lets the picture leave its box
        val c = Offset(700f, 400f)
        val before = CornerGeometry.toPicture(c, box, 1f, Offset.Zero, 1920, 1080)
        val (z, pn) = CornerGeometry.pinch(1f, Offset.Zero, 3f, c, Offset.Zero, box, 9f)
        val after = CornerGeometry.toPicture(c, box, z, pn, 1920, 1080)
        assertEquals(3f, z, 1e-4f);  assertEquals(before.x, after.x, 0.5f);  assertEquals(before.y, after.y, 0.5f)
        val (z2, p2) = CornerGeometry.pinch(3f, pn, 100f, c, Offset(50000f, 50000f), box, 9f)
        assertEquals(9f, z2, 1e-4f);  assertEquals(0f, p2.x, 0f);  assertEquals(0f, p2.y, 0f)
        val (z3, p3) = CornerGeometry.pinch(3f, pn, 0.01f, c, Offset.Zero, box, 9f)
        assertEquals(1f, z3, 0f);  assertEquals(Offset.Zero, p3)
    }

    @Test fun aTapAddsACornerMovesANearOneAndWithFourMovesTheNearest() {
        var t = listOf<Offset>()
        t = placeCorner(t, Offset(100f, 100f), 40f)
        t = placeCorner(t, Offset(900f, 120f), 40f)
        assertEquals(2, t.size)
        t = placeCorner(t, Offset(110f, 95f), 40f)                       // near the first: it moves
        assertEquals(2, t.size);  assertEquals(Offset(110f, 95f), t[0])
        t = placeCorner(t, Offset(880f, 700f), 40f)
        t = placeCorner(t, Offset(120f, 690f), 40f)
        assertEquals(4, t.size)
        t = placeCorner(t, Offset(500f, 650f), 40f)                      // four already: the nearest moves, none is added
        assertEquals(4, t.size);  assertEquals(Offset(500f, 650f), t[3])
    }

    @Test fun theAnswerIsExactlyWhatTheWorkerTakes() {
        val a = CornerJson.body(CornerAnswer.Accepted)
        assertEquals("accepted", a.getString("answer"));  assertEquals(1, a.length())
        val b = CornerJson.body(CornerAnswer.Corners(trueCorners))
        assertEquals("corners", b.getString("answer"));  assertEquals(2, b.length())
        val pts = b.getJSONArray("corners")
        assertEquals(4, pts.length())
        assertEquals(724.2, pts.getJSONArray(0).getDouble(0), 1e-9);  assertEquals(963.7, pts.getJSONArray(0).getDouble(1), 1e-9)
        assertTrue(runCatching { CornerJson.body(CornerAnswer.Corners(trueCorners.take(3))) }.isFailure)   // three corners are no answer
        // the cloud's own list form reads the same way
        val cloud = """[{"id":7,"sessionId":"s","cam":2,"picturePath":"calibration/cam2.jpg","width":960,"height":540,"support":0.2,"reason":"taps","lines":[[[1,2],[3,4]]],"url":"https://x"}]"""
        val c = CornerJson.read(cloud).single()
        assertEquals(7, c.id);  assertEquals(2, c.cam);  assertEquals("taps", c.reason);  assertEquals(Offset(3f, 4f), c.lines[0][1])
    }

    private fun state(): Map<String, String> {
        val s = rule.onNodeWithTag("cornerPicture").fetchSemanticsNode().config[SemanticsProperties.StateDescription]   // "corners n zoom z lines b"
        val w = s.split(" ")
        return mapOf("corners" to w[1], "zoom" to w[3], "lines" to w[5])
    }

    @Test fun fourTapsOnTheCornersGoToTheOutboxInPicturePixels() {
        val app = sampleApp()
        val nav = Navigator(Screen.Hub(SESSIONS))
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        rule.onNodeWithText("court corners").performScrollTo().performClick()       // the sessions page says a session is waiting
        rule.waitForIdle()
        assertEquals(Screen.CourtCorners, nav.current)
        val pic = rule.onNodeWithTag("cornerPicture")
        val box = pic.fetchSemanticsNode().size
        assertEquals(1920f / 1080f, box.width.toFloat() / box.height, 0.01f)        // the picture keeps its shape
        assertEquals("0", state()["corners"]);  assertEquals("true", state()["lines"])
        rule.onNodeWithText("none tapped yet").assertExists()
        val waiting = app.vision.outbox.size()
        rule.onNodeWithText("use these corners").performClick()                      // not four yet: the button does nothing
        rule.waitForIdle()
        assertEquals(waiting, app.vision.outbox.size())
        val k = box.width / 1920f
        trueCorners.shuffled(java.util.Random(3)).forEach { p ->
            pic.performTouchInput { click(Offset(p.x * k, p.y * k)) }
            rule.waitForIdle()
        }
        assertEquals("4", state()["corners"])
        rule.onNodeWithText("all four tapped").assertExists()
        rule.onNodeWithText("use these corners").performClick()
        rule.waitForIdle()
        val post = app.vision.outbox.read().let { it.getJSONObject(it.length() - 1) }
        assertEquals("/calibration/1/answer", post.getString("path"))
        val body = post.getJSONObject("body")
        assertEquals("corners", body.getString("answer"))
        val got = body.getJSONArray("corners").let { a -> (0 until a.length()).map { Offset(a.getJSONArray(it).getDouble(0).toFloat(), a.getJSONArray(it).getDouble(1).toFloat()) } }
        // each real corner has a tap within a screen pixel or so of it, in the picture's own pixels
        trueCorners.forEach { p -> assertTrue("$p in $got", got.any { (it - p).getDistance() < 2.5f / k }) }
        rule.onNodeWithText("Nothing is waiting", substring = true).assertExists()   // answered: the check is gone
        assertTrue(app.vision.cornerChecks(true).isEmpty())
    }

    @Test fun pinchZoomsForACloserTapAndTheLinesCanBeAcceptedOrHidden() {
        val app = sampleApp()
        val nav = Navigator(Screen.CourtCorners)
        rule.setContent { AppRoot(app, nav) }
        rule.waitForIdle()
        val pic = rule.onNodeWithTag("cornerPicture")
        pic.performTouchInput {
            pinch(center - Offset(20f, 0f), center - Offset(200f, 0f), center + Offset(20f, 0f), center + Offset(200f, 0f))
        }
        rule.waitForIdle()
        val zoom = state().getValue("zoom").toFloat()
        assertTrue("zoom $zoom", zoom > 2f)
        assertEquals("0", state()["corners"])                                        // a pinch is not a tap
        pic.performTouchInput { swipe(center, center + Offset(-200f, 0f), 400) }     // zoomed in, one finger pans: still no corner
        rule.waitForIdle()
        assertEquals("0", state()["corners"])
        pic.performTouchInput { click(center) }
        rule.waitForIdle()
        assertEquals("1", state()["corners"])
        rule.onNodeWithText("undo last tap").performScrollTo().performClick()
        rule.waitForIdle()
        assertEquals("0", state()["corners"])
        rule.onNodeWithText("zoom out").performScrollTo().performClick()
        rule.waitForIdle()
        assertEquals(1f, state().getValue("zoom").toFloat(), 1e-3f)
        rule.onNodeWithText("hide the lines").performScrollTo().performClick()
        rule.waitForIdle()
        assertEquals("false", state()["lines"])
        rule.onNodeWithText("show the lines").assertExists()
        rule.onNodeWithText("the lines are right").performScrollTo().performClick()
        rule.waitForIdle()
        val post = app.vision.outbox.read().let { it.getJSONObject(it.length() - 1) }
        assertEquals("/calibration/1/answer", post.getString("path"))
        assertEquals("accepted", post.getJSONObject("body").getString("answer"))
        assertFalse(post.getJSONObject("body").has("corners"))
    }
}
