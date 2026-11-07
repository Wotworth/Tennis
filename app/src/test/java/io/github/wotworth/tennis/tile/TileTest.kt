package io.github.wotworth.tennis.tile

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric

/** TIL-01, TIL-05 (v0.7): the tile's state, cues and back, and the provider. */
@RunWith(AndroidJUnit4::class)
class TileTest {

    @Test fun liveTileOnShowsCues() {
        val app = Sample.fill()
        assertEquals("cues", runBlocking { app.tileRow() }.state)
    }

    @Test fun liveTileOffShowsTheIcon() {
        val app = Sample.fill()
        app.prefs.chooseLiveTile(false)
        assertEquals("off", runBlocking { app.tileRow() }.state)
    }

    @Test fun aWaitingSessionTakesOverEvenWhenOff() {
        val app = Sample.fill(proposals = true)
        val p = app.repo.data.value.proposals.single()
        for (on in listOf(true, false)) {
            app.prefs.chooseLiveTile(on)
            val row = runBlocking { app.tileRow() }
            assertEquals("proposal", row.state)
            assertEquals("Tennis?", row.big)
            assertEquals(p.id.toString(), row.proposalId)
        }
    }

    @Test fun cuesPinnedFirstThenTheRest() {
        val cues = runBlocking { Sample.fill().tileCues() }
        assertEquals(7, cues.size)
        assertEquals(listOf(true, true, true, true, true, false, false), cues.map { it.pinned })
        assertEquals("Keep the racket face flat on the backswing.", cues.first().text)
    }

    @Test fun noBackFace() {
        // v0.8 (Chris, 7 Nov): cues only; an empty back row means the launcher shows no back.
        assertEquals("" to "", runBlocking { Sample.fill().tileBack() })
        assertEquals("" to "", runBlocking { Sample.empty().tileBack() })
    }

    @Test fun oldOffSettingCarriesOver() {
        val app = Sample.app()
        app.getSharedPreferences("settings", 0).edit().putInt("tileMode", io.github.wotworth.tennis.data.Prefs.TILE_OFF).remove("liveTile").commit()
        assertEquals(false, io.github.wotworth.tennis.data.Prefs(app).liveTile)
    }

    @Test fun providerAnswersTileCuesAndBack() {
        val app = Sample.fill()
        Robolectric.setupContentProvider(TileProvider::class.java, TileRows.AUTHORITY)
        val r = app.contentResolver
        r.query(TileRows.URI, null, null, null, null)!!.use { c -> c.moveToFirst(); assertEquals("cues", c.getString(c.getColumnIndexOrThrow("state"))) }
        r.query(TileCues.CUES, null, null, null, null)!!.use { c ->
            assertEquals(7, c.count); c.moveToFirst()
            assertEquals("forehand", c.getString(c.getColumnIndexOrThrow("heading")))
        }
        r.query(TileCues.BACK, null, null, null, null)!!.use { c -> c.moveToFirst(); assertEquals("", c.getString(c.getColumnIndexOrThrow("big"))) }
        r.query(TileRows.FACES, null, null, null, null)!!.use { assertEquals(1, it.count) }
    }
}
