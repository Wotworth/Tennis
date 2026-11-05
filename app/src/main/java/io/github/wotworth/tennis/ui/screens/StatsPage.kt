package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Stats
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.textStyleFor
import java.util.Locale

/** Section 9 (PH-5): current strings, feel over each job, tension against feel, and each year. */
@Composable
fun StatsPage() {
    val d = appData()
    val zpx = LocalZpx.current
    PivotColumn {
        if (d.loaded && d.jobs.isEmpty()) {
            TennisText("Hours, feel and spending.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Log a restring and a few sessions with a feel rating, and they show here.", TennisTokens.Type.listSecondary)
            return@PivotColumn
        }
        // STA-01
        Stats.current(d, Now.day()).forEach { c ->
            TextRow("${c.name}: ${Strings.hoursText(c.hours)} h", "${c.sessions} ${if (c.sessions == 1) "session" else "sessions"} · ${c.days} ${if (c.days == 1L) "day" else "days"} since the restring")
        }
        FeelChart(d)
        TensionFeel(d)
        // STA-04
        val years = Stats.years(d)
        if (years.isNotEmpty()) {
            SectionHeader("each year")
            years.forEach { y ->
                TextRow("${y.year}: ${y.restrings} ${if (y.restrings == 1) "restring" else "restrings"} · ${Strings.money(y.spentCents)}",
                    "${Strings.hoursText(y.avgHours)} h played per string job on average")
            }
        }
    }
}

private val highlight get() = TennisTokens.Colors.titleGradientStart

/** STA-02, STA-05: feel (1–5) against hours played, one line per string job of the shown racquet; the current one highlighted. */
@Composable
private fun FeelChart(d: AppData) {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    val racquet = d.racquet(app.prefs.selectedRacquet) ?: d.racquets.firstOrNull() ?: return
    val jobs = Strings.jobsFor(racquet.id, d.jobs).take(TennisTokens.Stats.jobsInChart)
    val lines = jobs.map { it to Stats.feelByHours(it, d) }.filter { it.second.isNotEmpty() }
    if (lines.isEmpty()) return
    SectionHeader("feel over each string job")
    TennisText(racquet.name, TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(zpx(6f)))
    val maxH = lines.maxOf { l -> l.second.maxOf { it.first } }.coerceAtLeast(1.0)
    val label = textStyleFor(TennisTokens.Type.listSecondary).let { it.copy(fontSize = it.fontSize * 0.75f) }
    val tm = rememberTextMeasurer()
    val current = jobs.firstOrNull()?.id
    Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Stats.chartHeight))) {
        val left = zpx(22f).toPx(); val bottom = size.height - zpx(18f).toPx(); val top = zpx(6f).toPx(); val right = size.width - zpx(4f).toPx()
        fun x(h: Double) = left + ((h / maxH) * (right - left)).toFloat()
        fun y(f: Int) = bottom - (f - 1) / 4f * (bottom - top)
        axes(left, right, top, bottom, zpx)
        for (f in 1..5) drawText(tm, "$f", Offset(0f, y(f) - zpx(7f).toPx()), label)
        drawText(tm, "0", Offset(left - zpx(3f).toPx(), bottom + zpx(3f).toPx()), label)
        drawText(tm, "${Strings.hoursText(maxH)} h", Offset(right - zpx(34f).toPx(), bottom + zpx(3f).toPx()), label)
        // Older jobs first, so the current one is drawn on top.
        lines.reversed().forEach { (job, pts) ->
            val c = if (job.id == current) highlight else TennisTokens.Colors.secondary
            val path = Path().apply { pts.forEachIndexed { i, (h, f) -> if (i == 0) moveTo(x(h), y(f)) else lineTo(x(h), y(f)) } }
            drawPath(path, c, style = Stroke(zpx(2f).toPx(), cap = StrokeCap.Square, join = StrokeJoin.Miter))
            pts.forEach { (h, f) -> drawCircle(c, zpx(2.5f).toPx(), Offset(x(h), y(f))) }
        }
    }
    Spacer(Modifier.height(zpx(4f)))
    TennisText("Current strings in green-yellow; earlier string jobs in grey.", TennisTokens.Type.listSecondary)
}

/** STA-03: each string job's mains tension against its average feel, and the same as a list. */
@Composable
private fun TensionFeel(d: AppData) {
    val zpx = LocalZpx.current
    val rows = Stats.jobFeels(d).filter { it.job.mainsLb != null }
    if (rows.isEmpty()) return
    SectionHeader("tension and feel")
    if (rows.size >= 2) {
        val lo = rows.minOf { it.job.mainsLb!! } - 1; val hi = rows.maxOf { it.job.mainsLb!! } + 1
        val label = textStyleFor(TennisTokens.Type.listSecondary).let { it.copy(fontSize = it.fontSize * 0.75f) }
        val tm = rememberTextMeasurer()
        val currents = d.racquets.mapNotNull { Strings.currentJob(it.id, d.jobs)?.id }.toSet()
        Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Stats.chartHeight))) {
            val left = zpx(22f).toPx(); val bottom = size.height - zpx(18f).toPx(); val top = zpx(6f).toPx(); val right = size.width - zpx(4f).toPx()
            fun x(lb: Double) = left + ((lb - lo) / (hi - lo) * (right - left)).toFloat()
            fun y(f: Double) = bottom - ((f - 1) / 4).toFloat() * (bottom - top)
            axes(left, right, top, bottom, zpx)
            for (f in 1..5) drawText(tm, "$f", Offset(0f, y(f.toDouble()) - zpx(7f).toPx()), label)
            drawText(tm, "${Strings.lb(lo)} lb", Offset(left - zpx(3f).toPx(), bottom + zpx(3f).toPx()), label)
            drawText(tm, "${Strings.lb(hi)} lb", Offset(right - zpx(36f).toPx(), bottom + zpx(3f).toPx()), label)
            rows.forEach { r -> drawCircle(if (r.job.id in currents) highlight else TennisTokens.Colors.primary, zpx(4f).toPx(), Offset(x(r.job.mainsLb!!), y(r.avgFeel))) }
        }
        Spacer(Modifier.height(zpx(8f)))
    }
    rows.forEach { r ->
        TextRow(
            "${Strings.tensionText(r.job)} lb · feel %.1f".format(Locale.US, r.avgFeel),
            listOfNotNull(Strings.shortDayText(r.job.date, Now.day()), d.racquet(r.job.racquetId)?.name, Strings.setupText(r.job), "${Strings.hoursText(r.hours)} h").joinToString(" · "),
        )
    }
}

private fun DrawScope.axes(left: Float, right: Float, top: Float, bottom: Float, z: io.github.wotworth.tennis.ui.theme.Zpx) {
    drawLine(TennisTokens.Colors.disabled, Offset(left, bottom), Offset(right, bottom), strokeWidth = 1.5f * density)
}
