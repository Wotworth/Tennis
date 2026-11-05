package io.github.wotworth.tennis.domain

import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.health.DayData
import io.github.wotworth.tennis.health.ExerciseRecord
import io.github.wotworth.tennis.health.HeartRateRecord
import io.github.wotworth.tennis.health.HeartRateSample
import io.github.wotworth.tennis.health.Origin
import io.github.wotworth.tennis.health.RestingRecord
import io.github.wotworth.tennis.health.StepsRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * DET-10 to DET-13, DET-31, built on the shape of Chris's 4 Nov report: Fitbit heart rate every
 * 2–3 s in one-minute records, the watch off for hours, steps from Fitbit and the phone, resting 68.
 */
class DetectionTest {
    private val zone = ZoneId.of("America/New_York")
    private val day = LocalDate.of(2026, 11, 4)
    private val fitbit = Origin("com.fitbit.FitbitMobile", recording = "recorded automatically")
    private val phone = Origin("com.android.healthconnect.phone.j9c9587f9439c3824b28aed13ef005763", "samsung SM-S931U1")
    private val s = DetectionSettings(birthYear = 1980)
    private fun at(h: Int, m: Int) = day.atTime(h, m).atZone(zone).toInstant()

    /** Readings every 2 s from [from] for [minutes], bpm from [bpm](minute index). */
    private fun hr(from: Instant, minutes: Int, bpm: (Int) -> Int): List<HeartRateRecord> = (0 until minutes).map { m ->
        val start = from.plusSeconds(m * 60L)
        HeartRateRecord(start, start.plusSeconds(58), (0 until 30).map { HeartRateSample(start.plusSeconds(it * 2L), bpm(m).toLong()) }, fitbit)
    }

    /** A day like 4 Nov: calm, a brisk 8-minute walk peaking at 140 (minute averages under 120), watch off 7:55–11:12. */
    private fun ordinaryDay(): List<HeartRateRecord> =
        hr(at(0, 30), 445) { 60 + it % 9 } + hr(at(11, 12), 220) { 72 + it % 11 } + hr(at(14, 54), 9) { listOf(95, 105, 112, 117, 119, 116, 110, 100, 90)[it] } + hr(at(15, 3), 120) { 75 + it % 7 }

    private fun base(extra: List<HeartRateRecord> = emptyList(), steps: List<StepsRecord> = emptyList(), ex: List<ExerciseRecord> = emptyList()) =
        DayData(day, zone, ordinaryDay() + extra, steps, ex, listOf(RestingRecord(at(6, 17), 68, fitbit)))

    @Test fun thresholdFromRestingAndAge() {
        // max 220 - 46 = 174; 68 + 0.5 × (174 - 68) = 121
        assertEquals(121, Detection.threshold(s, 68, 2026))
    }

    @Test fun ordinaryDayFindsNothing() {
        assertTrue(Detection.detect(base(), s, 2026).isEmpty())
    }

    @Test fun tennisFoundAndClipped() {
        // 85 minutes at 125–160 from 17:10, with a 3-minute water break at 140 → 100.
        val tennis = hr(at(17, 10), 85) { m -> if (m in 40..42) 100 else 125 + (m * 7) % 36 }
        val c = Detection.detect(base(tennis), s, 2026).single()
        assertEquals("heart_rate", c.source)
        assertEquals(at(17, 10).toEpochMilli(), c.startMillis)
        assertEquals(at(18, 35).toEpochMilli(), c.endMillis)
        assertTrue(c.maxHr!! >= 155)
    }

    @Test fun tooShortIsIgnored() {
        assertTrue(Detection.detect(base(hr(at(17, 10), 20) { 150 }), s, 2026).isEmpty())
    }

    @Test fun watchOffSplitsAWindow() {
        // Two 25-minute stretches with the watch off for 20 minutes between: neither is long enough.
        val a = hr(at(17, 0), 25) { 150 }; val b = hr(at(17, 45), 25) { 150 }
        assertTrue(Detection.detect(base(a + b), s, 2026).isEmpty())
    }

    @Test fun stepsPreferTheWatch() {
        val st = listOf(
            StepsRecord(at(17, 10), at(17, 11), 100, fitbit), StepsRecord(at(17, 30), at(17, 31), 50, fitbit),
            StepsRecord(at(17, 9), at(17, 15), 400, phone),
        )
        assertEquals(150L, Detection.steps(base(steps = st), at(17, 0).toEpochMilli(), at(18, 0).toEpochMilli()))
        assertEquals(200L, Detection.steps(base(steps = st.drop(2) + StepsRecord(at(16, 0), at(16, 4), 400, phone)), at(16, 0).toEpochMilli(), at(16, 2).toEpochMilli()))
    }

    @Test fun workoutWinsOverHeartRate() {
        val tennis = hr(at(17, 10), 85) { 140 }
        val ex = listOf(ExerciseRecord(at(17, 5), at(18, 40), 76, "tennis", null, fitbit))
        val c = Detection.detect(base(tennis, ex = ex), s, 2026).single()
        assertEquals("workout", c.source)
        assertEquals(at(17, 5).toEpochMilli(), c.startMillis)
    }

    @Test fun otherWorkoutsOnlyWhenAsked() {
        val ex = listOf(ExerciseRecord(at(9, 0), at(10, 0), 64, "squash", null, fitbit))
        assertTrue(Detection.detect(base(ex = ex), s, 2026).isEmpty())
        assertEquals(1, Detection.detect(base(ex = ex), s.copy(otherRacquetSports = true), 2026).size)
    }

    @Test fun loggedSessionsBlockProposals() {
        val c = Candidate(at(17, 10).toEpochMilli(), at(18, 35).toEpochMilli(), "heart_rate", 140, 160, null)
        val dayOf = { ms: Long -> Instant.ofEpochMilli(ms).atZone(zone).toLocalDate().toEpochDay() }
        assertTrue(Detection.filter(listOf(c), listOf(Busy(day.toEpochDay(), null, null)), dayOf).isEmpty())
        assertTrue(Detection.filter(listOf(c), listOf(Busy(day.toEpochDay(), at(18, 0).toEpochMilli(), at(19, 0).toEpochMilli())), dayOf).isEmpty())
        assertEquals(1, Detection.filter(listOf(c), listOf(Busy(day.toEpochDay(), at(9, 0).toEpochMilli(), at(10, 0).toEpochMilli())), dayOf).size)
    }

    @Test fun mergeGrowsWaitingAndRespectsAnswers() {
        val now = at(20, 0).toEpochMilli()
        val partial = Proposal(id = 1, startMillis = at(17, 10).toEpochMilli(), endMillis = at(17, 45).toEpochMilli(), source = "heart_rate", state = "waiting")
        val full = Candidate(at(17, 10).toEpochMilli(), at(18, 35).toEpochMilli(), "heart_rate", 140, 160, 5000)
        val m = Detection.merge(listOf(full), listOf(partial), s, now)
        assertEquals(at(18, 35).toEpochMilli(), m.update.single().endMillis)
        assertTrue(m.insert.isEmpty())
        val rejected = Detection.merge(listOf(full), listOf(partial.copy(state = "rejected")), s, now)
        assertTrue(rejected.insert.isEmpty() && rejected.update.isEmpty())
        assertEquals(1, Detection.merge(listOf(full), emptyList(), s, now).insert.size)
    }

    @Test fun oldWaitingProposalsExpire() {
        val old = Proposal(id = 7, startMillis = at(9, 0).toEpochMilli(), endMillis = at(10, 0).toEpochMilli(), source = "heart_rate")
        assertEquals(listOf(7L), Detection.merge(emptyList(), listOf(old), s, at(10, 0).toEpochMilli() + 8 * 86_400_000L).expire)
        assertTrue(Detection.merge(emptyList(), listOf(old), s, at(10, 0).toEpochMilli() + 6 * 86_400_000L).expire.isEmpty())
    }

    @Test fun debugTextForATennisDay() {
        val lines = io.github.wotworth.tennis.ui.screens.describe(base(hr(at(17, 10), 85) { 140 }), s, 2026)
        assertTrue(lines[0], lines[0].endsWith("resting 68 bpm; max 174; threshold 121 bpm"))
        assertTrue(lines.any { it.startsWith("found: 5:10 PM to 6:35 PM (1 h 25 min), heart rate") })
    }

    @Test fun learnedThresholdNeedsThreeSessions() {
        assertEquals(null, Detection.learnedThreshold(listOf(140, 138), s, 68))
        // Median 138 × 0.88 = 121.4 → 121.
        assertEquals(121, Detection.learnedThreshold(listOf(140, 138, 131), s, 68))
        // Never under resting + 15.
        assertEquals(98, Detection.learnedThreshold(listOf(90, 92, 95), s, 83))
        assertEquals(null, Detection.learnedThreshold(listOf(140, 138, 131), s.copy(learn = false), 68))
    }

    @Test fun learnedThresholdReplacesTheAgeEstimate() {
        // Someone whose real maximum is lower than 220 − age: sessions average ~125, so the age
        // threshold (121) is barely under play, and the learned one (110) sits clearly below it.
        // Median 124.5 × 0.88 = 109.6 → 110.
        val th = Detection.thresholdFor(s, 68, 2026, listOf(125, 124, 126, 123))
        assertEquals(110, th)
        val tennis = hr(at(17, 10), 85) { m -> if (m % 10 < 3) 112 else 128 }
        assertTrue(Detection.detect(base(tennis), s, 2026).isEmpty() || Detection.detect(base(tennis), s, 2026).single().minutes < 85)
        assertEquals(85, Detection.detect(base(tennis), s, 2026, th).single().minutes)
    }

    @Test fun bestWindowForAHandLoggedSession() {
        val tennis = hr(at(17, 10), 85) { 140 }
        val mins = Detection.perMinute(base(tennis))
        val (start, avg) = Detection.bestWindow(mins, 85)!!
        assertEquals(at(17, 10).toEpochMilli() / Detection.MINUTE, start)
        assertEquals(140.0, avg, 0.01)
        // Not enough readings for a window that long: none.
        assertEquals(null, Detection.bestWindow(Detection.perMinute(base(hr(at(17, 10), 20) { 140 }).copy(heartRate = hr(at(17, 10), 20) { 140 })), 85))
    }
}
