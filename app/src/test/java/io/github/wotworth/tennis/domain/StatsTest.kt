package io.github.wotworth.tennis.domain

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Section 9 on the sample data. */
@RunWith(AndroidJUnit4::class)
class StatsTest {

    @Test fun feelAgainstHoursOnTheCurrentJob() {
        val d = Sample.fill().repo.data.value
        val bb1 = d.racquets.first { it.name == "Black Blade #1" }
        val pts = Stats.feelByHours(Strings.currentJob(bb1.id, d.jobs)!!, d)
        assertEquals(listOf(1.5 to 5, 3.5 to 5, 5.0 to 4, 7.0 to 4, 8.5 to 4, 10.5 to 3, 12.0 to 3, 13.0 to 3), pts)
    }

    @Test fun tensionAgainstFeel() {
        val d = Sample.fill().repo.data.value
        val rows = Stats.jobFeels(d)
        // Newest first: Black Blade #2 (Oct 20), #1 hybrid (Oct 12), #1 September.
        assertEquals(listOf(52.0, 55.0, 54.0), rows.map { it.job.mainsLb })
        assertEquals(4.0, rows[2].avgFeel, 1e-9)
        assertEquals(5.0, rows[2].hours, 1e-9)
    }

    @Test fun eachYear() {
        val y = Stats.years(Sample.fill().repo.data.value).single()
        assertEquals(2026, y.year); assertEquals(3, y.restrings); assertEquals(10950L, y.spentCents)
        // (5 + 13 + 1) / 3 hours.
        assertEquals(19.0 / 3, y.avgHours, 1e-9)
    }

    @Test fun currentPerRacquet() {
        val c = Stats.current(Sample.fill().repo.data.value, Sample.today)
        assertEquals(listOf("Black Blade #1", "Black Blade #2"), c.map { it.name })
        assertEquals(8, c[0].sessions); assertEquals(24L, c[0].days)
    }
}
