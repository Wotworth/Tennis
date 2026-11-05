package io.github.wotworth.tennis.health

import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId

/** A made-up day like the one DET-01 should show: resting all day, a 85-minute tennis session at 5:10 PM. */
object FakeDays {
    val zone: ZoneId = ZoneId.of("America/New_York")
    val day: LocalDate = LocalDate.of(2026, 11, 4)
    private val fitbit = Origin("com.google.android.apps.fitness", "Google Charge 6", "recorded automatically")

    fun playedTennis(): DayData {
        val start = day.atTime(17, 10).atZone(zone).toInstant()
        val end = start.plus(Duration.ofMinutes(85))
        val morning = day.atTime(7, 0).atZone(zone).toInstant()
        val calm = (0 until 120).map { HeartRateSample(morning.plusSeconds(it * 300L), 58L + it % 7) }
        val play = (0 until 85 * 12).map { HeartRateSample(start.plusSeconds(it * 5L), 130L + (it * 7) % 38) }
        return DayData(
            day = day, zone = zone,
            heartRate = listOf(
                HeartRateRecord(calm.first().time, calm.last().time, calm, fitbit),
                HeartRateRecord(play.first().time, play.last().time, play, fitbit),
            ),
            steps = (0 until 24).map { h ->
                val s = day.atTime(h, 0).atZone(zone).toInstant()
                StepsRecord(s, s.plusSeconds(3600), if (h == 17) 6200 else 300, fitbit)
            },
            exercise = listOf(ExerciseRecord(start, end, 76, "tennis", "Tennis", fitbit.copy(recording = "recorded as a workout"))),
            restingHeartRate = listOf(RestingRecord(day.atTime(6, 0).atZone(zone).toInstant(), 56, fitbit)),
        )
    }
}
