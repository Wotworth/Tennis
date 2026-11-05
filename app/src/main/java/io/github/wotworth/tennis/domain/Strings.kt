package io.github.wotworth.tennis.domain

import io.github.wotworth.tennis.data.SessionWithRacquets
import io.github.wotworth.tennis.data.StringJob
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToLong

/** Pure rules for string jobs, sessions and hours (STR-05, SES-03, RAC-03). Unit-tested. */
object Strings {

    /** The racquet's jobs, newest first (latest date, then latest entered). */
    fun jobsFor(racquetId: Long, jobs: List<StringJob>): List<StringJob> =
        jobs.filter { it.racquetId == racquetId }.sortedWith(compareByDescending<StringJob> { it.date }.thenByDescending { it.id })

    fun currentJob(racquetId: Long, jobs: List<StringJob>): StringJob? = jobsFor(racquetId, jobs).firstOrNull()

    /**
     * STR-05: the job a session on [date] belongs to for this racquet: the newest job dated on or
     * before it. A session on a restring day counts for the new strings (DECISIONS 2026-11-05).
     */
    fun jobOn(racquetId: Long, date: Long, jobs: List<StringJob>): StringJob? =
        jobsFor(racquetId, jobs).firstOrNull { it.date <= date }

    /** The sessions that count toward [job]: on its racquet, from its date until the next job. */
    fun sessionsFor(job: StringJob, jobs: List<StringJob>, sessions: List<SessionWithRacquets>): List<SessionWithRacquets> =
        sessions.filter { s -> job.racquetId in s.racquetIds && jobOn(job.racquetId, s.session.date, jobs)?.id == job.id }

    /** RAC-03 (v0.4): hours on [job]: the full length of every session played with its racquet. */
    fun hours(job: StringJob, jobs: List<StringJob>, sessions: List<SessionWithRacquets>): Double =
        sessionsFor(job, jobs, sessions).sumOf { it.session.minutes / 60.0 }

    /** SES-03: one decimal, "14.5"; whole numbers without ".0" ("0", "12"). */
    fun hoursText(h: Double): String {
        val tenths = (h * 10).roundToLong()
        return if (tenths % 10 == 0L) "${tenths / 10}" else "${tenths / 10}.${tenths % 10}"
    }

    /** Feel ratings on [job], oldest first (STA-02, the strings page's trend tile). */
    fun feels(job: StringJob, jobs: List<StringJob>, sessions: List<SessionWithRacquets>): List<Int> =
        sessionsFor(job, jobs, sessions).sortedWith(compareBy({ it.session.date }, { it.session.startMillis ?: 0 }, { it.session.id }))
            .mapNotNull { it.session.feel }

    /**
     * The feel trend: the average of the last [recent] ratings against the average of the ones
     * before them. "up", "down", "steady", or null with fewer than two ratings.
     */
    fun feelTrend(feels: List<Int>, recent: Int = 3, margin: Double = 0.25): String? {
        if (feels.size < 2) return null
        val n = minOf(recent, feels.size - 1)
        val last = feels.takeLast(n).average()
        val before = feels.dropLast(n).average()
        return when {
            last > before + margin -> "up"
            last < before - margin -> "down"
            else -> "steady"
        }
    }

    /** "55" or "55.5": tension without a needless ".0". */
    fun lb(v: Double?): String = when {
        v == null -> "–"
        v % 1.0 == 0.0 -> v.toLong().toString()
        else -> "%.1f".format(Locale.US, v)
    }

    /** "55/53", or "55" when mains and crosses match. */
    fun tensionText(job: StringJob): String =
        if (job.mainsLb == job.crossesLb || job.crossesLb == null) lb(job.mainsLb) else "${lb(job.mainsLb)}/${lb(job.crossesLb)}"

    /** "$20.00" from cents. */
    fun money(cents: Long?): String = if (cents == null) "" else "$%d.%02d".format(Locale.US, cents / 100, cents % 100)

    /** Parses "20", "20.5", "$20.50" to cents; null if not a price. */
    fun parseMoney(text: String): Long? {
        val t = text.trim().removePrefix("$").trim()
        if (t.isEmpty()) return null
        val v = t.toBigDecimalOrNull() ?: return null
        if (v.signum() < 0) return null
        return v.movePointRight(2).setScale(0, java.math.RoundingMode.HALF_UP).toLong()
    }

    /** "Solinco Hyper-G 16L", or "Solinco Hyper-G 16L / Luxilon Alu Power 125" for a hybrid. */
    fun setupText(job: StringJob): String {
        fun one(s: io.github.wotworth.tennis.data.StringSpec) = listOf(s.name, s.gauge).filter { it.isNotBlank() }.joinToString(" ").ifBlank { "strings not named" }
        return if (job.hybrid) "${one(job.mains)} / ${one(job.crossesOwn)}" else one(job.mains)
    }

    fun day(epochDay: Long): LocalDate = LocalDate.ofEpochDay(epochDay)
    fun dayText(epochDay: Long): String = DateTimeFormatter.ofPattern("EEE d MMM yyyy", Locale.US).format(day(epochDay))
    fun shortDayText(epochDay: Long, today: Long): String {
        val d = day(epochDay)
        return if (d.year == day(today).year) DateTimeFormatter.ofPattern("EEE d MMM", Locale.US).format(d) else DateTimeFormatter.ofPattern("d MMM yyyy", Locale.US).format(d)
    }

    /** "1 h 25 min", "45 min", "2 h". */
    fun minutesText(m: Int): String = when {
        m < 60 -> "$m min"
        m % 60 == 0 -> "${m / 60} h"
        else -> "${m / 60} h ${m % 60} min"
    }
}
