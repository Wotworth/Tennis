package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import io.github.wotworth.tennis.ui.components.FitText
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
 * Chris, 17 Nov: the summary opens with the session's key figures (accuracy, first and second
 * serves, topspin, speed), each against the average of his earlier sessions and of the last
 * ten, so a good day stands out; the session's trends tab shows each figure over time.
 */

/** The session's day (UTC date of its start), to tell earlier sessions from later ones. */
fun sessionDay(v: VisionSession): Long = runCatching { Instant.parse(v.startUtc).atZone(ZoneOffset.UTC).toLocalDate().toEpochDay() }.getOrDefault(0L)

/** One figure: its group and label, how to read it, and its unit on screen. */
private enum class Unit { FT, MPH, PCT }
private class Figure(val group: String, val label: String, val unit: Unit, val higherIsBetter: Boolean = true,
                     val spinKind: ((SessionMetrics) -> String?)? = null, val get: (SessionMetrics) -> Double?) {
    /** The value in the units shown (ft, mph or %), for the trend charts. */
    fun shown(v: Double) = when (unit) { Unit.FT -> v * Units.FT_PER_M; Unit.MPH -> v * Units.MPH_PER_MS; Unit.PCT -> v }
    fun show(v: Double): String = when (unit) { Unit.FT -> Units.ft(v); Unit.MPH -> Units.mph(v); Unit.PCT -> "${v.roundToInt()}%" }
    /** A chart's axis label in the same form (ft with one decimal below 10, mph and % whole). */
    fun axis(x: Double): String = if (unit == Unit.FT && kotlin.math.abs(x) < 10) "%.1f".format(java.util.Locale.US, x) else "${x.roundToInt()}"
}

// Chris, 17 Nov: in this order; serves first and second apart. Depth is how far short of the
// baseline the ball landed, so smaller is deeper (better).
private val FIGURES = listOf(
    Figure("accuracy", "shots in, not serves", Unit.PCT) { it.inPct?.toDouble() },
    Figure("accuracy", "short of the baseline", Unit.FT, higherIsBetter = false) { it.depth },
    Figure("first serves", "in", Unit.PCT) { it.serve1InPct?.toDouble() },
    Figure("first serves", "speed", Unit.MPH) { it.serve1Speed },
    Figure("first serves", "spin, shorter", Unit.FT, spinKind = { it.serve1SpinKind }) { it.serve1Spin },
    Figure("second serves", "in", Unit.PCT) { it.serve2InPct?.toDouble() },
    Figure("second serves", "speed", Unit.MPH) { it.serve2Speed },
    Figure("second serves", "spin, shorter", Unit.FT, spinKind = { it.serve2SpinKind }) { it.serve2Spin },
    Figure("topspin", "forehand, shorter", Unit.FT) { it.topspinForehand },
    Figure("topspin", "backhand, shorter", Unit.FT) { it.topspinBackhand },
    Figure("speed", "forehand", Unit.MPH) { it.speedForehand },
    Figure("speed", "backhand", Unit.MPH) { it.speedBackhand },
)

/** This session's figures, the average of all earlier sessions, of the last [RECENT] of them (when there are more), and the points. */
private data class History(val now: SessionMetrics, val avg: SessionMetrics?, val recent: SessionMetrics?, val points: List<Pair<Long, SessionMetrics>>)

/** Chris, 17 Nov: "your average" is shown two ways: all earlier sessions, and the last 10. */
private const val RECENT = 10

@Composable
private fun history(v: VisionSession, me: String): History {
    val app = LocalApp.current
    val day = sessionDay(v)
    val earlier = app.vision.trends(v.sample).filter { it.epochDay < day }.mapNotNull { p -> p.metrics?.let { p.epochDay to it } }.sortedBy { it.first }
    return History(SessionMetrics.of(v, me), earlier.takeIf { it.isNotEmpty() }?.let { SessionMetrics.average(it.map { e -> e.second }) },
        earlier.takeIf { it.size > RECENT }?.let { SessionMetrics.average(it.takeLast(RECENT).map { e -> e.second }) }, earlier)
}

/**
 * The summary's key figures as tiles (Chris, 17 Nov: less text): the figure, what it is, and
 * one short line with both averages (all earlier sessions; the last ten). A tile is tile green
 * when the session beat the average of all earlier sessions, dark grey otherwise; the arrow says
 * which way the number moved (for depth, down is deeper).
 */
@Composable
fun KeyFigures(v: VisionSession, me: String) {
    val zpx = LocalZpx.current
    val h = history(v, me)
    TennisText(if (h.avg == null) "Your first session: from the next one on, each figure is compared with your average."
        else "Green: better than your average. avg: all earlier sessions" + (if (h.recent != null) "; ten: the last ten." else "."),
        TennisTokens.Type.listSecondary)
    FIGURES.groupBy { it.group }.forEach { (group, figs) ->
        Spacer(Modifier.height(zpx(10f)))
        TennisText(group, TennisTokens.Type.sectionHeader)
        Spacer(Modifier.height(zpx(4f)))
        val cols = if (figs.size == 3) 3 else 2
        Row(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.IntrinsicSize.Min)) {
            figs.forEachIndexed { k, f ->
                if (k > 0) Spacer(Modifier.width(zpx(TennisTokens.Layout.tileGap)))
                FigureTile(f, h, Modifier.weight(1f).fillMaxHeight(), small = cols == 3)
            }
        }
    }
}

@Composable
private fun FigureTile(f: Figure, h: History, modifier: Modifier, small: Boolean) {
    val zpx = LocalZpx.current
    val now = f.get(h.now)
    val avg = h.avg?.let { f.get(it) }
    val better = now != null && avg != null && f.show(now) != f.show(avg) && ((now > avg) == f.higherIsBetter)
    Column(modifier.background(if (better) TennisTokens.Colors.tile else TennisTokens.Colors.segmentOff).padding(zpx(8f))) {
        // spin that makes a serve land longer (slice, flat) shows as "longer", not a negative "shorter"
        val longer = f.spinKind != null && now != null && now < 0
        val role = if (small) TennisTokens.Type.tileNumberSmall else TennisTokens.Type.statNumber
        // a fixed height: FitText measures its width first, which the row's equal heights can't ask it
        FitText((now?.let { if (longer) f.show(-it) else f.show(it) }) ?: "–", role, Modifier.fillMaxWidth().height(zpx(role.sizeZpx * 1.35f)))
        val kind = f.spinKind?.invoke(h.now)?.let { if (it.startsWith("flat")) "flat" else it }
        TennisText(if (kind != null) "$kind, ${if (longer) "longer" else "shorter"}" else f.label, TennisTokens.Type.tileFigureLabel, maxLines = 2)
        if (now != null && avg != null) {
            val arrow = when { f.show(now) == f.show(avg) -> "="; now > avg -> "▲"; else -> "▼" }
            Spacer(Modifier.weight(1f))
            val line = Modifier.fillMaxWidth().height(zpx(TennisTokens.Type.tileFigureLabel.sizeZpx * 1.4f))
            FitText("$arrow avg ${f.show(avg)}", TennisTokens.Type.tileFigureLabel, line)
            h.recent?.let { f.get(it) }?.let { r -> FitText("ten ${f.show(r)}", TennisTokens.Type.tileFigureLabel, line) }
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
        TennisText("Each session's figure; this one in green. Grey: the average of the last ten sessions at each point, so you can see which way it's heading." +
            (racquet?.let { " Dashed: restrings of ${it.name}, with the tension." } ?: ""), TennisTokens.Type.listSecondary)
        FIGURES.groupBy { it.group }.forEach { (group, figs) ->
            SectionHeader(group)
            figs.forEach { f ->
                val pts = (h.points.mapNotNull { (dd, m) -> f.get(m)?.let { dd to f.shown(it) } } +
                    listOfNotNull(f.get(h.now)?.let { day to f.shown(it) })).sortedBy { it.first }
                if (pts.size >= 2) {
                    TrendChart(f.label, pts, jobs, highlight = day, format = { x -> f.axis(x) }, caption = false, rollingAverage = RECENT)
                    Spacer(Modifier.height(zpx(10f)))
                }
            }
        }
    }
}
