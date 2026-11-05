package io.github.wotworth.tennis.domain

import io.github.wotworth.tennis.data.Session
import io.github.wotworth.tennis.data.SessionWithRacquets
import io.github.wotworth.tennis.data.StringJob
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** STR-05, SES-03, RAC-03: which strings a session counts for, and hours. */
class StringsTest {
    private val sept = StringJob(id = 1, racquetId = 1, date = 100)
    private val oct = StringJob(id = 2, racquetId = 1, date = 130)
    private val other = StringJob(id = 3, racquetId = 2, date = 120)
    private val jobs = listOf(sept, oct, other)
    private fun s(id: Long, date: Long, min: Int, vararg r: Long, feel: Int? = null) = SessionWithRacquets(Session(id = id, date = date, minutes = min, feel = feel), r.toList())

    @Test fun currentIsNewest() {
        assertEquals(oct, Strings.currentJob(1, jobs))
        assertNull(Strings.currentJob(9, jobs))
    }

    @Test fun sessionOnRestringDayCountsForNewStrings() {
        assertEquals(oct, Strings.jobOn(1, 130, jobs))
        assertEquals(sept, Strings.jobOn(1, 129, jobs))
        assertNull(Strings.jobOn(1, 99, jobs))
    }

    @Test fun hoursOnlyFromThatRacquetsSessions() {
        val sessions = listOf(s(1, 131, 90, 1), s(2, 132, 60, 2), s(3, 125, 120, 1))
        assertEquals(1.5, Strings.hours(oct, jobs, sessions), 1e-9)
        assertEquals(2.0, Strings.hours(sept, jobs, sessions), 1e-9)
        assertEquals(1.0, Strings.hours(other, jobs, sessions), 1e-9)
    }

    @Test fun twoRacquetsShareTheSession() {
        val sessions = listOf(s(1, 131, 120, 1, 2))
        assertEquals(1.0, Strings.hours(oct, jobs, sessions), 1e-9)
        assertEquals(1.0, Strings.hours(other, jobs, sessions), 1e-9)
    }

    @Test fun hoursText() {
        assertEquals("0", Strings.hoursText(0.0))
        assertEquals("14.5", Strings.hoursText(14.49))
        assertEquals("12", Strings.hoursText(12.02))
    }

    @Test fun feelsInOrderAndTrend() {
        val sessions = listOf(s(3, 140, 60, 1, feel = 2), s(1, 131, 60, 1, feel = 5), s(2, 135, 60, 1, feel = 4), s(4, 141, 60, 1))
        val f = Strings.feels(oct, jobs, sessions)
        assertEquals(listOf(5, 4, 2), f)
        assertEquals("down", Strings.feelTrend(f))
        assertEquals("up", Strings.feelTrend(listOf(2, 2, 4, 5)))
        assertEquals("steady", Strings.feelTrend(listOf(4, 4)))
        assertNull(Strings.feelTrend(listOf(4)))
    }

    @Test fun tensionAndMoney() {
        assertEquals("55/53", Strings.tensionText(oct.copy(mainsLb = 55.0, crossesLb = 53.0)))
        assertEquals("52", Strings.tensionText(oct.copy(mainsLb = 52.0, crossesLb = 52.0)))
        assertEquals("52.5", Strings.lb(52.5))
        assertEquals(3850L, Strings.parseMoney("$38.50"))
        assertEquals(2000L, Strings.parseMoney("20"))
        assertNull(Strings.parseMoney("abc"))
        assertEquals("$38.50", Strings.money(3850))
    }
}
