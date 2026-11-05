package io.github.wotworth.tennis.health

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * DET-01: one day of Health Connect data as plain values, independent of the Health Connect
 * library so the summary and the dump can be unit-tested. [HealthSource] fills it from the phone.
 */
data class DayData(
    val day: LocalDate,
    val zone: ZoneId,
    val heartRate: List<HeartRateRecord> = emptyList(),
    val steps: List<StepsRecord> = emptyList(),
    val exercise: List<ExerciseRecord> = emptyList(),
    val restingHeartRate: List<RestingRecord> = emptyList(),
)

/** Who wrote a record: the app's package and, when given, the device. */
data class Origin(val packageName: String, val device: String? = null, val recording: String? = null) {
    override fun toString() = buildString {
        append(packageName)
        if (device != null) append(" on ").append(device)
        if (recording != null) append(" (").append(recording).append(')')
    }
}

data class HeartRateSample(val time: Instant, val bpm: Long)
data class HeartRateRecord(val start: Instant, val end: Instant, val samples: List<HeartRateSample>, val origin: Origin)
data class StepsRecord(val start: Instant, val end: Instant, val count: Long, val origin: Origin)
data class ExerciseRecord(val start: Instant, val end: Instant, val type: Int, val typeName: String, val title: String?, val origin: Origin)
data class RestingRecord(val time: Instant, val bpm: Long, val origin: Origin)

object HealthReport {

    /** The median gap between consecutive heart-rate samples across the day, or null with fewer than 2. */
    fun medianSampleGap(records: List<HeartRateRecord>): Duration? {
        val times = records.flatMap { r -> r.samples.map { it.time } }.sorted()
        if (times.size < 2) return null
        val gaps = times.zipWithNext { a, b -> Duration.between(a, b) }.sorted()
        return gaps[gaps.size / 2]
    }

    /** The median length of step records, or null if none. */
    fun medianStepsInterval(records: List<StepsRecord>): Duration? {
        if (records.isEmpty()) return null
        val lengths = records.map { Duration.between(it.start, it.end) }.sorted()
        return lengths[lengths.size / 2]
    }

    /** Short "5 s", "1 min", "1 min 30 s", "2 h" text for a gap or an interval. */
    fun durationText(d: Duration): String {
        val s = d.seconds
        return when {
            s < 60 -> "$s s"
            s < 3600 -> if (s % 60 == 0L) "${s / 60} min" else "${s / 60} min ${s % 60} s"
            else -> if (s % 3600 == 0L) "${s / 3600} h" else "${s / 3600} h ${(s % 3600) / 60} min"
        }
    }

    /** Counts per writing app, most first: "com.fitbit.FitbitMobile (12)". */
    fun originCounts(origins: List<Origin>): String =
        origins.groupingBy { it.packageName }.eachCount().entries
            .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .joinToString(", ") { "${it.key} (${it.value})" }

    private fun time(t: Instant, zone: ZoneId) = DateTimeFormatter.ofPattern("H:mm", Locale.US).withZone(zone).format(t)
    private fun timeSec(t: Instant, zone: ZoneId) = DateTimeFormatter.ofPattern("H:mm:ss", Locale.US).withZone(zone).format(t)

    fun dayTitle(day: LocalDate): String = DateTimeFormatter.ofPattern("EEE d MMM yyyy", Locale.US).format(day)

    /**
     * The on-screen summary: one block per data type, in plain lines (DET-01). Each block is a
     * heading and its lines, so the screen can set the heading in the list style.
     */
    fun summary(d: DayData): List<Pair<String, List<String>>> {
        val z = d.zone
        val hr = d.heartRate
        val samples = hr.flatMap { it.samples }.sortedBy { it.time }
        val hrLines = if (samples.isEmpty()) listOf("none") else buildList {
            add("${samples.size} readings in ${hr.size} records, ${time(samples.first().time, z)} to ${time(samples.last().time, z)}")
            medianSampleGap(hr)?.let { add("usually ${durationText(it)} apart") }
            val max = samples.maxBy { it.bpm }
            add("highest ${max.bpm} bpm at ${time(max.time, z)}; lowest ${samples.minOf { it.bpm }} bpm")
            add("from " + originCounts(hr.map { it.origin }))
        }
        val stLines = if (d.steps.isEmpty()) listOf("none") else buildList {
            add("${d.steps.sumOf { it.count }} steps in ${d.steps.size} records")
            medianStepsInterval(d.steps)?.let { add("records usually ${durationText(it)} long") }
            add("from " + originCounts(d.steps.map { it.origin }))
        }
        val exLines = if (d.exercise.isEmpty()) listOf("none") else d.exercise.sortedBy { it.start }.map {
            val title = it.title?.takeIf { t -> t.isNotBlank() }?.let { t -> " \"$t\"" } ?: ""
            "${it.typeName}$title, ${time(it.start, z)} to ${time(it.end, z)} (${durationText(Duration.between(it.start, it.end))}), from ${it.origin.packageName}"
        }
        val rLines = if (d.restingHeartRate.isEmpty()) listOf("none") else d.restingHeartRate.sortedBy { it.time }.map {
            "${it.bpm} bpm at ${time(it.time, z)}, from ${it.origin.packageName}"
        }
        return listOf(
            "heart rate" to hrLines,
            "steps" to stLines,
            "workouts" to exLines,
            "resting heart rate" to rLines,
        )
    }

    /** The full dump shared as a text file: the summary, then every record and every sample. */
    fun dump(d: DayData, header: String): String = buildString {
        val z = d.zone
        appendLine("Tennis String Log: Health Connect report (DET-01)")
        appendLine(header)
        appendLine("day: ${dayTitle(d.day)}, time zone ${z.id}")
        appendLine()
        for ((heading, lines) in summary(d)) {
            appendLine("== $heading")
            lines.forEach { appendLine("  $it") }
        }
        appendLine()
        appendLine("== workout records")
        d.exercise.sortedBy { it.start }.forEach {
            appendLine("${timeSec(it.start, z)} to ${timeSec(it.end, z)}  type ${it.type} ${it.typeName}  title ${it.title ?: "-"}  origin ${it.origin}")
        }
        appendLine()
        appendLine("== resting heart rate records")
        d.restingHeartRate.sortedBy { it.time }.forEach { appendLine("${timeSec(it.time, z)}  ${it.bpm} bpm  origin ${it.origin}") }
        appendLine()
        appendLine("== step records")
        d.steps.sortedBy { it.start }.forEach {
            appendLine("${timeSec(it.start, z)} to ${timeSec(it.end, z)}  ${it.count}  origin ${it.origin}")
        }
        appendLine()
        appendLine("== heart rate records (every reading)")
        d.heartRate.sortedBy { it.start }.forEach { r ->
            appendLine("record ${timeSec(r.start, z)} to ${timeSec(r.end, z)}, ${r.samples.size} readings, origin ${r.origin}")
            r.samples.sortedBy { it.time }.forEach { appendLine("  ${timeSec(it.time, z)} ${it.bpm}") }
        }
    }
}
