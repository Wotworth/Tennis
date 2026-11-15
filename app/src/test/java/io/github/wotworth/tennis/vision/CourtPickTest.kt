package io.github.wotworth.tennis.vision

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Chris, 15 Nov: a court picked before playing labels the next vision session that overlaps that time. */
class CourtPickTest {
    private val h = 3_600_000L
    private val sessions = listOf(
        CourtPick.Span("yesterday", 0, 2 * h),
        CourtPick.Span("today", 26 * h, 28 * h),
        CourtPick.Span("tomorrow", 50 * h, 52 * h),
    )

    @Test fun picksTheNextSessionAfterThePick() =
        assertEquals("today", CourtPick.match(sessions, 25 * h, emptySet(), 12f))

    @Test fun aPickDuringPlayStillCounts() =
        assertEquals("today", CourtPick.match(sessions, 27 * h, emptySet(), 12f))

    @Test fun aSessionAlreadyLabelledIsSkipped() =
        assertEquals("tomorrow", CourtPick.match(sessions, 25 * h, setOf("today"), 30f))

    @Test fun nothingWithinTheWindowMeansNoLabelYet() =
        assertNull(CourtPick.match(sessions, 29 * h, emptySet(), 12f))

    @Test fun anOlderSessionIsNeverLabelled() =
        assertNull(CourtPick.match(sessions.take(1), 25 * h, emptySet(), 12f))
}
