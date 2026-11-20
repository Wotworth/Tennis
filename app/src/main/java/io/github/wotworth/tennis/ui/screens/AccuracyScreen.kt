package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.AccuracyResult
import io.github.wotworth.tennis.vision.AccuracyStore
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The accuracy page (Chris, 22 Nov, item 14): tools/groundTruthReport.m's numbers for one test
 * session, each beside the truth it was checked against. One section per test, as text rows.
 */
@Composable
fun AccuracyScreen() {
    val app = LocalApp.current
    val all = remember { AccuracyStore(app).all() }
    var pick by remember { mutableIntStateOf(0) }
    AccuracyContent(all, pick) { pick = it }
}

/** The day of a result file, with "sample (synthetic)" when it is made up. */
fun accuracyDay(r: AccuracyResult): String {
    val day = runCatching { DateTimeFormatter.ofPattern("EEE d MMM yyyy", Locale.US).format(LocalDate.parse(r.session)) }.getOrDefault(r.session.ifBlank { "no date" })
    return if (r.synthetic) "sample (synthetic) · $day" else day
}

@Composable
fun AccuracyContent(all: List<AccuracyResult>, pick: Int, onPick: (Int) -> Unit) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Type
    val m = TennisTokens.Measure
    Page("accuracy") {
        val r = all.getOrNull(pick) ?: all.firstOrNull()
        if (r == null) { TennisText("No accuracy results on the phone yet.", t.listPrimary); return@Page }
        if (all.size > 1) {
            ChoiceRow("session", all.indices.map { it to accuracyDay(all[it]) }, setOf(pick), onPick)
        }
        TennisText(accuracyDay(r), t.listPrimary)
        Spacer(Modifier.height(zpx(4f)))
        TennisText(
            if (r.synthetic) "Made-up numbers, to show the page. The PC's real results from Tuesday replace them."
            else "The PC's accuracy report: each number beside the truth it was checked against.",
            t.listSecondary,
        )

        fun cm(v: Double?) = num(v, m.cmDecimals) + " cm"

        SectionHeader("drop")
        val d = r.drop
        if (d == null) NotDone() else {
            TextRow("gravity ${num(d.g, m.gDecimals)} m/s²",
                "truth ${num(d.gTruth, m.gDecimals)} m/s² · spread ${num(d.gSpread, m.gDecimals)} · ${d.n ?: "–"} drops")
            val diffCm = if (d.heightM != null && d.heightTruthM != null) (d.heightM - d.heightTruthM) * 100 else null
            TextRow("release height ${num(d.heightM, m.heightDecimals)} m",
                "truth ${num(d.heightTruthM, m.heightDecimals)} m (2.00 m to the ball's bottom)" +
                    (diffCm?.let { " · ${num(kotlin.math.abs(it), m.cmDecimals)} cm ${if (it < 0) "low" else "high"}" } ?: "") +
                    " · spread ${cm(d.heightSpreadM?.times(100))}")
        }

        SectionHeader("still balls")
        if (r.still.isEmpty()) NotDone()
        r.still.forEach { b ->
            TextRow(b.name, if (b.found) "found · ${cm(b.errCm)} from its true spot · sight lines ${cm(b.gapCm)} apart" else "not found")
        }

        SectionHeader("targets")
        if (r.targets.isEmpty()) NotDone()
        r.targets.forEach { g ->
            TextRow(g.name, "${g.n ?: "–"} bounces found · from the cross: median ${cm(g.medianCm)}, worst ${cm(g.worstCm)}")
        }

        SectionHeader("machine spread")
        if (r.machine.isEmpty()) NotDone()
        r.machine.forEach { c ->
            TextRow(c.setting, "${c.n ?: "–"} shots · speed ${num(c.speedMph, m.mphDecimals)} mph ± ${num(c.speedSdMph, m.mphDecimals)} · " +
                "spin effect ${num(c.spinFt, m.ftDecimals)} ft ± ${num(c.spinSdFt, m.ftDecimals)} · landing spread ${cm(c.landSdCm)}")
        }

        SectionHeader("camera positions against the tape")
        if (r.cameras.isEmpty()) NotDone()
        r.cameras.forEach { c -> TextRow("camera ${c.cam}", "${cm(c.errCm)} from where the tape put it") }

        r.spin?.let { s ->
            SectionHeader("spin")
            TennisText("Each striped ball: rpm counted from the stripe against the system's rpm" +
                (s.medianDiffRpm?.let { " · median difference ${num(it, 0)} rpm" } ?: "") +
                ". Inside the band: the stripe's count is within twice the system's ± of its rpm.", t.listSecondary)
            Spacer(Modifier.height(zpx(8f)))
            s.rows.forEach { b ->
                TextRow("striped ball ${b.ball}", "stripe ${num(b.stripeRpm, 0)} ± ${num(b.stripeSdRpm, 0)} rpm · system ${num(b.systemRpm, 0)} ± ${num(b.systemSdRpm, 0)} rpm · " +
                    "inside the band: ${when (b.inside) { true -> "yes"; false -> "no"; null -> "–" }}")
            }
        }
    }
}

@Composable
private fun NotDone() {
    TennisText("not done in this session", TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(LocalZpx.current(TennisTokens.Layout.listRowGap)))
}

private fun num(v: Double?, decimals: Int) = v?.let { "%.${decimals}f".format(Locale.US, it) } ?: "–"
