package io.github.wotworth.tennis.vision

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.data.Cue
import io.github.wotworth.tennis.tile.TileCues
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.file.Files

/** Chris, 15 Nov: ball checks, flags, opponents and the tile's lowest-priority state. */
@RunWith(AndroidJUnit4::class)
class FeedbackTest {
    @Test fun checkAnswersAreWhatTheWorkerAccepts() {
        assertEquals("ok", Feedback.checkBody(1, CheckAnswer.Ok).getString("answer"))
        val m = Feedback.checkBody(1, CheckAnswer.Moved(140.0, 101.0))
        assertEquals("moved", m.getString("answer")); assertEquals(140.0, m.getDouble("x"), 0.0)
        assertEquals("none", Feedback.checkBody(1, CheckAnswer.NoBall).getString("answer"))
    }

    @Test fun looksWrongTakesOnlyTheFourReasons() {
        assertEquals("wrong speed", Feedback.looksWrong(3, 2, "wrong speed").getString("reason"))
        assertTrue(runCatching { Feedback.looksWrong(3, 2, "bad vibes") }.isFailure)
        assertEquals(812.4, Feedback.missedShot(4, 812.4).getDouble("t"), 0.0)
    }

    @Test fun theOutboxHoldsTapsButNoNames() {
        val dir = Files.createTempDirectory("ob").toFile()
        val o = Outbox(dir)
        val opp = Opponents()
        val p = opp.add("Test Opponent One")
        o.add("/sessions/s1/opponent", Feedback.opponent(p.id))
        o.add("/sessions/s1/flags", Feedback.looksWrong(1, 1, "wrong call"))
        val text = dir.listFiles()!!.joinToString { it.readText() }
        assertEquals(2, o.size())
        assertFalse(text.contains("Test Opponent"))
    }

    @Test fun theSuggestionIsLastSessionAtTheSameCourtAndNeverChosen() {
        val history = listOf(Triple("2026-11-01", 7L, 2), Triple("2026-11-08", 7L, 3), Triple("2026-11-10", 9L, 4))
        assertEquals(3, Feedback.suggest(7L, history))
        assertNull(Feedback.suggest(null, history))
        val o = Opponents()
        assertFalse(o.answered("s1"))            // nothing is assigned until Chris taps
    }

    @Test fun renameAndMergeReachPastSessions() {
        val o = Opponents()
        val a = o.add("Test Opponent One"); val b = o.add("Test Opponent 1")
        o.choose("s1", a.id); o.choose("s2", b.id)
        o.rename(b.id, "Test Opponent Uno")
        assertEquals("Test Opponent Uno", o.of("s2")!!.name)
        o.merge(a.id, b.id)
        assertEquals(b.id, o.of("s1")!!.id)
        o.delete(b.id)
        assertNull(o.of("s1")); assertTrue(o.answered("s1"))
    }

    @Test fun framesToCheckShowOnlyWhenTheTileWouldBeThePlainIcon() {
        val none = AppData(loaded = true)
        assertEquals("checks", TileCues.state(none, liveTile = true, now = 0, checks = 12).state)
        assertEquals("off", TileCues.state(none, liveTile = false, now = 0, checks = 12).state)
        val withCues = AppData(cues = listOf(Cue(id = 1, heading = "forehand", text = "Follow through.")), loaded = true)
        assertEquals("cues", TileCues.state(withCues, liveTile = true, now = 0, checks = 12).state)
    }

    /** Chris, 20 Nov: a session held for the court corners shows on the live tile, ahead of the cues. */
    @Test fun aSessionWaitingForCornersShowsAheadOfTheCues() {
        val withCues = AppData(cues = listOf(Cue(id = 1, heading = "forehand", text = "Follow through.")), loaded = true)
        val t = TileCues.state(withCues, liveTile = true, now = 0, checks = 12, corners = 1)
        assertEquals("checks", t.state)
        assertEquals("1", t.big);  assertEquals("session waiting: corners", t.small)
        assertEquals("off", TileCues.state(withCues, liveTile = false, now = 0, corners = 1).state)
    }
}
