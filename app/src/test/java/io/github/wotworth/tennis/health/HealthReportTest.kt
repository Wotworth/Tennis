package io.github.wotworth.tennis.health

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.Instant

/** DET-01: the report's numbers. */
class HealthReportTest {

    private val o = Origin("a.b")

    @Test fun medianGapOfFiveSecondReadings() {
        val t0 = Instant.parse("2026-11-04T22:00:00Z")
        val r = HeartRateRecord(t0, t0, (0 until 10).map { HeartRateSample(t0.plusSeconds(it * 5L), 120) }, o)
        assertEquals(Duration.ofSeconds(5), HealthReport.medianSampleGap(listOf(r)))
    }

    @Test fun medianGapAcrossRecordsInTimeOrder() {
        val t0 = Instant.parse("2026-11-04T22:00:00Z")
        val late = HeartRateRecord(t0, t0, listOf(HeartRateSample(t0.plusSeconds(120), 1), HeartRateSample(t0.plusSeconds(180), 1)), o)
        val early = HeartRateRecord(t0, t0, listOf(HeartRateSample(t0, 1), HeartRateSample(t0.plusSeconds(60), 1)), o)
        assertEquals(Duration.ofSeconds(60), HealthReport.medianSampleGap(listOf(late, early)))
    }

    @Test fun noGapWithOneReading() {
        val t0 = Instant.parse("2026-11-04T22:00:00Z")
        assertNull(HealthReport.medianSampleGap(listOf(HeartRateRecord(t0, t0, listOf(HeartRateSample(t0, 1)), o))))
        assertNull(HealthReport.medianStepsInterval(emptyList()))
    }

    @Test fun durationText() {
        assertEquals("5 s", HealthReport.durationText(Duration.ofSeconds(5)))
        assertEquals("1 min", HealthReport.durationText(Duration.ofSeconds(60)))
        assertEquals("1 min 30 s", HealthReport.durationText(Duration.ofSeconds(90)))
        assertEquals("1 h 25 min", HealthReport.durationText(Duration.ofMinutes(85)))
        assertEquals("2 h", HealthReport.durationText(Duration.ofHours(2)))
    }

    @Test fun originsMostFirst() {
        assertEquals("x (2), y (1)", HealthReport.originCounts(listOf(Origin("y"), Origin("x"), Origin("x"))))
    }

    @Test fun summaryOfATennisDay() {
        val s = HealthReport.summary(FakeDays.playedTennis()).toMap()
        assertEquals("1140 readings in 2 records, 7:00 to 18:34", s.getValue("heart rate")[0])
        assertEquals("usually 5 s apart", s.getValue("heart rate")[1])
        assertTrue(s.getValue("heart rate")[2], s.getValue("heart rate")[2].startsWith("highest 167 bpm"))
        assertEquals("13100 steps in 24 records", s.getValue("steps")[0])
        assertEquals("records usually 1 h long", s.getValue("steps")[1])
        assertEquals("tennis \"Tennis\", 17:10 to 18:35 (1 h 25 min), from com.google.android.apps.fitness", s.getValue("workouts")[0])
        assertEquals("56 bpm at 6:00, from com.google.android.apps.fitness", s.getValue("resting heart rate")[0])
    }

    @Test fun emptyDaySaysNone() {
        val s = HealthReport.summary(DayData(FakeDays.day, FakeDays.zone))
        assertTrue(s.all { it.second == listOf("none") })
    }

    @Test fun dumpHasEveryReadingAndTheDevice() {
        val text = HealthReport.dump(FakeDays.playedTennis(), "app: test")
        assertTrue(text.contains("day: Wed 4 Nov 2026, time zone America/New_York"))
        assertTrue(text.contains("on Google Charge 6 (recorded automatically)"))
        assertTrue(text.contains("type 76 tennis"))
        assertEquals(1140, Regex("^  \\d+:\\d\\d:\\d\\d \\d+$", RegexOption.MULTILINE).findAll(text).count())
    }
}
