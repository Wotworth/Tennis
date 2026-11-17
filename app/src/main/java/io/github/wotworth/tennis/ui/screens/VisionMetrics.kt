package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.SessionMetrics
import io.github.wotworth.tennis.vision.Units
import io.github.wotworth.tennis.vision.VisionSession
import java.time.Instant
import java.time.ZoneOffset
import kotlin.math.roundToInt

/*
 * Chris, 17 Nov: the summary opens with the session's key figures (topspin, speed, serves,
 * accuracy), each against the average of his earlier sessions, so a good day stands out; the
 * session's trends tab shows each figure over time, this session marked.
 */

/** The session's day (UTC date of its start), to tell earlier sessions from later ones. */
fun sessionDay(v: VisionSession): Long = runCatching { Instant.parse(v.startUtc).atZone(ZoneOffset.UTC).toLocalDate().toEpochDay() }.getOrDefault(0L)

/** One figure: its group and label, how to read it, and its unit on screen. */
private enum class Unit { FT, MPH, PCT }
private class Figure(val group: String, val label: String, val unit: Unit, val get: (SessionMetrics) -> Double?) {
    /** The value in the units shown (ft, mph or %), for the trend charts. */
    fun shown(v: Double) = when (unit) { Unit.FT -> v * Units.FT_PER_M; Unit.MPH -> v * Units.MPH_PER_MS; Unit.PCT -> v }
    fun show(v: Double): String = when (unit) { Unit.FT -> Units.ft(v); Unit.MPH -> Units.mph(v); Unit.PCT -> "${v.roundToInt()}%" }
    /** A chart's axis label in the same form (ft with one decimal below 10, mph and % whole). */
    fun axis(x: Double): String = if (unit == Unit.FT && kotlin.math.abs(x) < 10) "%.1f".format(java.util.Locale.US, x) else "${x.roundToInt()}"
}

private val FIGURES = listOf(
    Figure("topspin", "forehand, ft shorter", Unit.FT) { it.topspinForehand },
    Figure("topspin", "backhand, ft shorter", Unit.FT) { it.topspinBackhand },
    Figure("speed", "forehand", Unit.MPH) { it.speedForehand },
    Figure("speed", "backhand", Unit.MPH) { it.speedBackhand },
    Figure("serves", "in", Unit.PCT) { it.serveInPct?.toDouble() },
    Figure("serves", "speed", Unit.MPH) { it.serveSpeed },
    Figure("serves", "spin, ft shorter", Unit.FT) { it.serveSpin },
    Figure("accuracy", "shots in, not serves", Unit.PCT) { it.inPct?.toDouble() },
    Figure("accuracy", "depth inside the baseline", Unit.FT) { it.depth },
)

private data class History(val now: SessionMetrics, val avg: SessionMetrics?, val points: List<Pair<Long, SessionMetrics>>)

@Composable
private fun history(v: VisionSession, me: String): History {
    val app = LocalApp.current
    val day = sessionDay(v)
    val earlier = app.vision.trends(v.sample).filter { it.epochDay < day }.mapNotNull { p -> p.metrics?.let { p.epochDay to it } }
    return History(SessionMetrics.of(v, me), earlier.takeIf { it.isNotEmpty() }?.let { SessionMetrics.average(it.map { e -> e.second }) }, earlier)
}

/** The summary's key figures: this session's, against the average of the earlier ones. */
@Composable
fun KeyFigures(v: VisionSession, me: String) {
    val zpx = LocalZpx.current
    val h = history(v, me)
    TennisText(if (h.avg == null) "Your first session: from the next one on, each figure is compared with your average."
        else "This session against the average of your earlier sessions.", TennisTokens.Type.listSecondary)
    FIGURES.groupBy { it.group }.forEach { (group, figs) ->
        SectionHeader(group)
        figs.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth().padding(bottom = zpx(9f))) {
                row.forEach { f ->
                    val now = f.get(h.now)
                    val avg = h.avg?.let { f.get(it) }
                    Column(Modifier.weight(1f).padding(end = zpx(8f))) {
                        TennisText(now?.let { f.show(it) } ?: "–", TennisTokens.Type.statNumber, maxLines = 1)
                        val label = if (group == "serves" && f.label.startsWith("spin") && h.now.serveSpinKind != null) "${h.now.serveSpinKind} spin, ft shorter" else f.label
                        TennisText(label, TennisTokens.Type.statLabel, maxLines = 2)
                        if (now != null && avg != null) {
                            val a = f.show(avg);  val n = f.show(now)
                            val word = when {
                                a == n -> "same as"
                                now > avg -> "above"
                                else -> "below"
                            }
                            TennisText("$word your average, $a", TennisTokens.Type.listSecondary, maxLines = 2)
                        }
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

/** The session's trends tab: each key figure over the sessions, this one marked. */
@Composable
fun SessionTrends(v: VisionSession, me: String?) {
    val zpx = LocalZpx.current
    val d = io.github.wotworth.tennis.ui.appData()
    val app = LocalApp.current
    PivotColumn {
        if (me == null) {
            TennisText("Answer \"which one is you?\" on the summary first: until then this session isn't yours to compare.", TennisTokens.Type.listPrimary)
            return@PivotColumn
        }
        val h = history(v, me)
        val day = sessionDay(v)
        val racquet = d.racquet(app.prefs.selectedRacquet ?: -1) ?: d.active.firstOrNull()
        val jobs = d.jobs.filter { it.racquetId == racquet?.id }
        TennisText("Each session's figure; this one in green." + (racquet?.let { " Dashed: restrings of ${it.name}, with the tension." } ?: ""), TennisTokens.Type.listSecondary)
        FIGURES.groupBy { it.group }.forEach { (group, figs) ->
            SectionHeader(group)
            figs.forEach { f ->
                val pts = (h.points.mapNotNull { (dd, m) -> f.get(m)?.let { dd to f.shown(it) } } +
                    listOfNotNull(f.get(h.now)?.let { day to f.shown(it) })).sortedBy { it.first }
                if (pts.size >= 2) {
                    TrendChart(f.label, pts, jobs, highlight = day, format = { x -> f.axis(x) }, caption = false)
                    Spacer(Modifier.height(zpx(10f)))
                }
            }
        }
    }
}
