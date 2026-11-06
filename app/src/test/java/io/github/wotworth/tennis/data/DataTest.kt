package io.github.wotworth.tennis.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.domain.Strings
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files

/** DAT-01, DAT-02, RAC-01 to RAC-03 against the real database. */
@RunWith(AndroidJUnit4::class)
class DataTest {

    @Test fun sampleHoursPerRacquet() {
        val app = Sample.fill()
        val d = app.repo.data.value
        val bb1 = d.racquets.first { it.name == "Black Blade #1" }
        val bb2 = d.racquets.first { it.name == "Black Blade #2" }
        // 90+120+90+120+90+120+90+120 = 840 min (v0.4: one racquet per session, no split).
        assertEquals("14", Strings.hoursText(Strings.hours(Strings.currentJob(bb1.id, d.jobs)!!, d.jobs, d.sessions)))
        assertEquals("1", Strings.hoursText(Strings.hours(Strings.currentJob(bb2.id, d.jobs)!!, d.jobs, d.sessions)))
    }

    @Test fun libraryFilledFromJobs() {
        val d = Sample.fill().repo.data.value
        assertEquals(setOf("Hyper-G", "Alu Power", "RPM Blast", "4G"), d.strings.map { it.spec.model }.toSet())
    }

    @Test fun deletingARacquetKeepsItsSessionsWithoutIt() {
        val app = Sample.fill()
        val bb2 = app.repo.data.value.racquets.first { it.name == "Black Blade #2" }
        runBlocking { app.repo.deleteRacquet(bb2) }
        // Wait for the racquet and its session links to go (two tables, published separately).
        Sample.waitFor(app) { d -> d.racquets.size == 3 && d.sessions.none { bb2.id in it.racquetIds } && d.jobs.none { it.racquetId == bb2.id } }
        val d = app.repo.data.value
        assertEquals(12, d.sessions.size)
        assertTrue(d.jobs.none { it.racquetId == bb2.id })
        assertTrue(d.sessions.none { bb2.id in it.racquetIds })
    }

    @Test fun exportThenImportRestoresEverything() {
        val app = Sample.fill()
        val before = runBlocking { app.repo.snapshot() }
        val photos = Files.createTempDirectory("p").toFile().also { File(it, "a.jpg").writeText("jpeg") }
        val zip = ByteArrayOutputStream().also { Backup.write(before, photos, it) }.toByteArray()
        val back = Files.createTempDirectory("q").toFile()
        val read = Backup.read(ByteArrayInputStream(zip), back)
        assertEquals(before, read)
        assertEquals("jpeg", File(back, "a.jpg").readText())
        runBlocking { app.repo.replaceAll(BackupData()) }
        Sample.waitFor(app) { it.racquets.isEmpty() }
        runBlocking { app.repo.replaceAll(read) }
        Sample.waitFor(app) { it.sessions.size == 12 }
        assertEquals(before, runBlocking { app.repo.snapshot() })
    }

    @Test fun oneRacquetPerSession() {
        val app = Sample.fill()
        val d = app.repo.data.value
        assertTrue(d.sessions.all { it.racquetIds.size == 1 })
        val s = d.sessions.first()
        runBlocking { app.repo.saveSession(s.session, listOf(d.racquets[0].id, d.racquets[1].id)) }
        Sample.waitFor(app) { it.sessions.first { x -> x.session.id == s.session.id }.racquetIds == listOf(d.racquets[0].id) }
    }

    @Test fun retiredRacquetsKeepTheirHistory() {
        val d = Sample.fill().repo.data.value
        assertEquals(listOf("Old Pro Staff"), d.retired.map { it.name })
        assertEquals(listOf("Black Blade #1", "Black Blade #2", "Pure Aero"), d.active.map { it.name })
        assertEquals(1, d.jobs.count { it.racquetId == d.retired[0].id })
    }
}
