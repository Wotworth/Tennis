package io.github.wotworth.tennis.domain

import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.data.StringJob
import java.time.LocalDate

/** Section 9: the numbers behind the stats page. Pure and unit-tested. */
object Stats {

    /** STA-02: a job's feel ratings against hours played on it so far (hours at the end of each rated session). */
    fun feelByHours(job: StringJob, d: AppData): List<Pair<Double, Int>> {
        var hours = 0.0
        return Strings.sessionsFor(job, d.jobs, d.sessions)
            .sortedWith(compareBy({ it.session.date }, { it.session.startMillis ?: 0 }, { it.session.id }))
            .mapNotNull { s ->
                hours += s.session.minutes / 60.0
                s.session.feel?.let { hours to it }
            }
    }

    /** STA-03: one row per job with at least one feel rating. */
    data class JobFeel(val job: StringJob, val avgFeel: Double, val hours: Double, val ratings: Int)

    fun jobFeels(d: AppData): List<JobFeel> = d.jobs.mapNotNull { j ->
        val f = Strings.feels(j, d.jobs, d.sessions)
        if (f.isEmpty()) null else JobFeel(j, f.average(), Strings.hours(j, d.jobs, d.sessions), f.size)
    }.sortedByDescending { it.job.date }

    /** STA-04: one row per calendar year with a restring, newest first. */
    data class Year(val year: Int, val restrings: Int, val spentCents: Long, val avgHours: Double)

    fun years(d: AppData): List<Year> = d.jobs.groupBy { LocalDate.ofEpochDay(it.date).year }.map { (y, js) ->
        Year(y, js.size, js.sumOf { it.priceCents ?: 0 }, js.map { Strings.hours(it, d.jobs, d.sessions) }.average())
    }.sortedByDescending { it.year }

    /** STA-01 per racquet: hours on the current strings, sessions on them, days since the restring. */
    data class Current(val racquetId: Long, val name: String, val hours: Double, val sessions: Int, val days: Long)

    fun current(d: AppData, today: Long): List<Current> = d.active.mapNotNull { r ->
        val j = Strings.currentJob(r.id, d.jobs) ?: return@mapNotNull null
        Current(r.id, r.name, Strings.hours(j, d.jobs, d.sessions), Strings.sessionsFor(j, d.jobs, d.sessions).size, today - j.date)
    }
}
