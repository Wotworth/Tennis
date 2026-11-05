package io.github.wotworth.tennis.tile

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.data.Racquet
import io.github.wotworth.tennis.data.Session
import io.github.wotworth.tennis.data.StringJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric

/** TIL-01, TIL-02, TIL-12: the tile row and the provider. */
@RunWith(AndroidJUnit4::class)
class TileTest {

    @Test fun hoursForTheRacquetPlayedLast() {
        val app = Sample.fill()
        // The last session (4 Nov) was with Black Blade #1.
        val row = runBlocking { app.tileRow() }
        assertEquals("hours", row.state)
        assertEquals("14", row.big)
        assertEquals("hours · Black Blade #1", row.small)
    }

    @Test fun proposalComesFirst() {
        val app = Sample.fill(proposals = true)
        val p = app.repo.data.value.proposals.single()
        val row = runBlocking { app.tileRow() }
        assertEquals(TileRow("proposal", "Tennis?", row.small, p.id.toString(), row.updated), row)
    }

    @Test fun emptyWithoutStrings() {
        val app = Sample.empty()
        assertEquals("empty", runBlocking { app.tileRow() }.state)
    }

    @Test fun oneRacquetSaysHoursOnTheseStrings() {
        val d = io.github.wotworth.tennis.data.AppData(
            racquets = listOf(Racquet(1, "A")), jobs = listOf(StringJob(1, 1, 10)),
            sessions = listOf(io.github.wotworth.tennis.data.SessionWithRacquets(Session(1, 11, 90), listOf(1))), loaded = true,
        )
        assertEquals(TileRow("hours", "1.5", "hours on these strings", null, 5), TileRows.of(d, emptyList(), 0, 5))
        val waiting = d.copy(proposals = listOf(Proposal(id = 3, startMillis = 0, endMillis = 1, source = "heart_rate")))
        assertEquals(TileRow("proposal", "Tennis?", "w", "3", 5), TileRows.of(waiting, emptyList(), 0, 5) { "w" })
    }

    @Test fun providerAnswersTheRow() {
        val app = Sample.fill()
        Robolectric.setupContentProvider(TileProvider::class.java, TileRows.AUTHORITY)
        app.contentResolver.query(TileRows.URI, null, null, null, null)!!.use { c ->
            c.moveToFirst()
            assertEquals("hours", c.getString(c.getColumnIndexOrThrow("state")))
            assertEquals("14", c.getString(c.getColumnIndexOrThrow("big")))
            assertEquals(true, c.isNull(c.getColumnIndexOrThrow("proposal_id")))
        }
    }

    @Test fun facesFlipThroughActiveRacquetsWhenAsked() {
        val app = Sample.fill()
        assertEquals(1, runBlocking { app.tileFaces() }.size)
        app.prefs.chooseTileFlips(true)
        val faces = runBlocking { app.tileFaces() }
        // Black Blade #1 (played last) first, then #2; Pure Aero has no strings; the retired racquet is left out.
        assertEquals(listOf("hours · Black Blade #1", "hours · Black Blade #2"), faces.map { it.small })
        assertEquals(listOf("14", "1"), faces.map { it.big })
        Robolectric.setupContentProvider(TileProvider::class.java, TileRows.AUTHORITY)
        app.contentResolver.query(TileRows.FACES, null, null, null, null)!!.use { assertEquals(2, it.count) }
    }

    @Test fun aWaitingProposalIsTheOnlyFace() {
        val app = Sample.fill(proposals = true)
        app.prefs.chooseTileFlips(true)
        assertEquals(listOf("proposal"), runBlocking { app.tileFaces() }.map { it.state })
    }
}
