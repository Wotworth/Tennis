package io.github.wotworth.tennis.ui.screens

import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.core.content.FileProvider
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.DateField
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.ToggleSwitch
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.FieldNotes
import io.github.wotworth.tennis.vision.FieldNotesStore
import io.github.wotworth.tennis.vision.MachineClip
import io.github.wotworth.tennis.vision.MiniJson
import io.github.wotworth.tennis.vision.NoteStill
import io.github.wotworth.tennis.vision.Target
import io.github.wotworth.tennis.vision.TargetSide
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate

/**
 * Tuesday's measurements (Chris, 22 Nov, item 9; docs/USER-MANUAL.md 16.3): a form in Tuesday's
 * order that writes vision/groundtruth/<date>.json for the PC's accuracy report. The draft saves
 * itself to filesDir/groundtruth/<date>.json on every change and comes back when the page opens.
 */
@Composable
fun FieldNotesScreen() {
    val context = LocalContext.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    val store = remember { FieldNotesStore(File(context.filesDir, "groundtruth")) }
    val today = Now.day()
    val loaded = remember { runCatching { store.latest() }.getOrNull() }
    var notes by remember { mutableStateOf(loaded ?: FieldNotes(LocalDate.ofEpochDay(today).toString())) }
    // one write at a time, in order; the last date written, so a changed date moves the file
    val writer = remember { Dispatchers.IO.limitedParallelism(1) }
    val lastDate = remember { arrayOf(loaded?.session) }
    LaunchedEffect(notes) {
        val n = notes
        withContext(writer) { runCatching { store.save(n, lastDate[0]); lastDate[0] = n.session } }
    }
    FieldNotesContent(
        notes, today,
        onChange = { notes = it },
        onShare = {
            val n = notes
            scope.launch {
                val uri = withContext(writer) {
                    store.save(n, lastDate[0]); lastDate[0] = n.session
                    val dir = File(context.cacheDir, "groundtruth").apply { mkdirs() }
                    val f = File(dir, "${n.session}.json")
                    f.writeText(n.toJson())
                    FileProvider.getUriForFile(context, "io.github.wotworth.tennis.files", f)
                }
                val send = Intent(Intent.ACTION_SEND).setType("application/json").putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                context.startActivity(Intent.createChooser(send, null))
            }
        },
        onClear = {
            o.confirm("start afresh?", "Every number on this sheet is cleared, and its file on the phone with it.", "clear") {
                notes = FieldNotes(LocalDate.ofEpochDay(today).toString())
            }
        },
    )
}

/** The form itself, from plain values (the screenshot test supplies them). */
@Composable
fun FieldNotesContent(n: FieldNotes, today: Long, onChange: (FieldNotes) -> Unit, onShare: () -> Unit, onClear: () -> Unit) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Type
    val m = TennisTokens.Measure
    Page("tuesday") {
        TennisText("Fill this in at the court; it saves as you type. Distances in metres unless a box says cm.", t.listSecondary)
        Spacer(Modifier.height(zpx(12f)))
        val day = runCatching { LocalDate.parse(n.session).toEpochDay() }.getOrDefault(today)
        DateField("session day (names the file)", day, { onChange(n.copy(session = LocalDate.ofEpochDay(it).toString())) }, today = maxOf(today, day))
        FileRows(n, onShare, null)

        // 1. cameras (step 1)
        SectionHeader("cameras")
        Hint("Measured with the tape once both are mounted (step 1).")
        Spacer(Modifier.height(zpx(8f)))
        n.cameras.forEachIndexed { i, c ->
            fun set(nc: io.github.wotworth.tennis.vision.NoteCamera) = onChange(n.copy(cameras = n.cameras.toMutableList().also { it[i] = nc }))
            ItemTitle("camera ${c.cam}")
            NumberBox("height above the court", c.heightM, { set(c.copy(heightM = it)) })
            NumberBox("from the doubles sideline, straight across", c.fromDoublesSidelineM, { set(c.copy(fromDoublesSidelineM = it)) })
            NumberBox("from the baseline line extended, along", c.beyondBaselineM, { set(c.copy(beyondBaselineM = it)) })
            ChoiceRow("beyond the", listOf("near" to "near baseline", "far" to "far baseline"), setOf(c.atEnd), { set(c.copy(atEnd = it)) })
            Spacer(Modifier.height(zpx(m.itemGap)))
        }

        // 2. court (step 2)
        SectionHeader("court")
        val cm = 100.0
        NumberBox("baseline width (cm)", n.court.baselineWidthM?.times(cm), { onChange(n.copy(court = n.court.copy(baselineWidthM = it?.div(cm)))) })
        NumberBox("one service line's width (cm)", n.court.serviceLineWidthM?.times(cm), { onChange(n.copy(court = n.court.copy(serviceLineWidthM = it?.div(cm)))) })
        NumberBox("between the doubles sidelines, at one baseline", n.court.doublesWidthM, { onChange(n.copy(court = n.court.copy(doublesWidthM = it))) })

        // 3. still balls (clip 1, step 4)
        SectionHeader("still balls · clip 1")
        Hint("Their spots are fixed by the lines: " + NoteStill.ALL.joinToString("; ") { it.name } + ".")
        Spacer(Modifier.height(zpx(8f)))
        NumberBox("seconds into the clip when all are still", n.still.atS, { onChange(n.copy(still = n.still.copy(atS = it))) })
        ToggleSwitch("ball on the net tape (off if it wouldn't balance)", n.still.netTape) { onChange(n.copy(still = n.still.copy(netTape = it))) }

        // 4. drops (clip 2, step 5)
        SectionHeader("drops · clip 2")
        NumberBox("release height, to the ball's bottom", n.drops.releaseHeightM?.minus(FieldNotes.BALL_RADIUS),
            { onChange(n.copy(drops = n.drops.copy(releaseHeightM = it?.let { v -> FieldNotes.round4(v + FieldNotes.BALL_RADIUS) }))) })
        n.drops.spots.forEachIndexed { i, s ->
            NumberBox("drops at the ${s.name}", s.count?.toDouble(), { v ->
                onChange(n.copy(drops = n.drops.copy(spots = n.drops.spots.toMutableList().also { it[i] = s.copy(count = v?.toInt()) })))
            })
        }

        // 5. targets (clip 3, step 6)
        SectionHeader("targets · clip 3")
        Hint("Each cross's centre: from the far baseline, and from the doubles sideline on its side (your side: the cameras' side).")
        Spacer(Modifier.height(zpx(8f)))
        n.targets.spots.forEachIndexed { i, s ->
            fun set(ns: Target?) = onChange(n.copy(targets = n.targets.copy(spots = n.targets.spots.toMutableList().also { if (ns == null) it.removeAt(i) else it[i] = ns })))
            key(i) {
                TextBox("target ${i + 1}", s.name, { set(s.copy(name = it)) }, singleLine = false)
                ChoiceRow(null, listOf(TargetSide.CAMERAS to "your side", TargetSide.CENTRE to "centre", TargetSide.OTHER to "other side"), setOf(s.side),
                    { set(s.copy(side = it, fromSidelineM = if (it == TargetSide.CENTRE) null else s.fromSidelineM)) })
                Row(Modifier.fillMaxWidth()) {
                    NumberBox("from the baseline", s.fromBaselineM, { set(s.copy(fromBaselineM = it)) }, Modifier.weight(1f))
                    Spacer(Modifier.width(zpx(m.pairGap)))
                    if (s.side == TargetSide.CENTRE) Column(Modifier.weight(1f)) {}
                    else NumberBox("from the sideline", s.fromSidelineM, { set(s.copy(fromSidelineM = it)) }, Modifier.weight(1f))
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    TennisText("x ${metres(s.x)}, y ${metres(s.y)}", t.listSecondary, Modifier.weight(1f))
                    SmallAction("remove") { set(null) }
                }
                Spacer(Modifier.height(zpx(m.itemGap)))
            }
        }
        SmallAction("add a target") {
            onChange(n.copy(targets = n.targets.copy(spots = n.targets.spots + Target("", TargetSide.CENTRE, null, null))))
        }

        // 6. machine clips (clips 4 to 7, step 7)
        SectionHeader("machine clips")
        Hint("For each clip: the dials, the feed, the elevation and where the machine stood (from the far centre mark). A change of place carries to the clips below that were in the same place.")
        Spacer(Modifier.height(zpx(8f)))
        n.machine.forEachIndexed { i, c ->
            fun set(nc: MachineClip?) = onChange(n.copy(machine = n.machine.toMutableList().also { if (nc == null) it.removeAt(i) else it[i] = nc }))
            fun place(nc: MachineClip) = onChange(n.copy(machine = n.machine.mapIndexed { j, o ->
                when {
                    j == i -> nc
                    j > i && o.x == c.x && o.y == c.y -> o.copy(alongM = nc.alongM, behind = nc.behind, acrossM = nc.acrossM, acrossOther = nc.acrossOther)
                    else -> o
                }
            }))
            key(i) {
                ItemTitle(c.clip.replace("clip", "clip "))
                TextBox("setting", c.setting, { set(c.copy(setting = it)) })
                Row(Modifier.fillMaxWidth()) {
                    NumberBox("speed dial", c.speedDial, { set(c.copy(speedDial = it)) }, Modifier.weight(1f))
                    Spacer(Modifier.width(zpx(m.pairGap)))
                    NumberBox("spin dial", c.spinDial, { set(c.copy(spinDial = it)) }, Modifier.weight(1f))
                }
                Row(Modifier.fillMaxWidth()) {
                    NumberBox("a ball every (s)", c.feedS, { set(c.copy(feedS = it)) }, Modifier.weight(1f))
                    Spacer(Modifier.width(zpx(m.pairGap)))
                    NumberBox("elevation (°)", c.elevationDeg, { set(c.copy(elevationDeg = it)) }, Modifier.weight(1f))
                }
                NumberBox("from the far centre mark, along the court", c.alongM, { place(c.copy(alongM = it)) })
                ChoiceRow(null, listOf(true to "behind baseline", false to "in the court"), setOf(c.behind), { place(c.copy(behind = it)) })
                NumberBox("across, from the centre line", c.acrossM, { place(c.copy(acrossM = it)) })
                if ((c.acrossM ?: 0.0) > 0.0) {
                    ChoiceRow(null, listOf(false to "towards the cameras' side", true to "towards the other side"), setOf(c.acrossOther), { place(c.copy(acrossOther = it)) })
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    TennisText("x ${metres(c.x)}, y ${metres(c.y)}", t.listSecondary, Modifier.weight(1f))
                    SmallAction("remove") { set(null) }
                }
                Spacer(Modifier.height(zpx(m.itemGap)))
            }
        }
        SmallAction("add a machine clip") {
            val next = (n.machine.mapNotNull { it.clip.removePrefix("clip").toIntOrNull() }.maxOrNull() ?: 3) + 1
            val last = n.machine.lastOrNull()
            onChange(n.copy(machine = n.machine + MachineClip("clip$next", "", alongM = last?.alongM, behind = last?.behind ?: true,
                acrossM = last?.acrossM ?: 0.0, acrossOther = last?.acrossOther ?: false)))
        }

        // 7. spin (optional, clip 8, step 9)
        SectionHeader("spin (optional) · clip 8")
        ToggleSwitch("striped balls filmed by the Hero 7", n.spin != null) { onChange(n.withSpin(it)) }
        n.spin?.let { s ->
            TextBox("Hero 7 file (e.g. HERO7/GH010001.MP4)", s.file, { onChange(n.copy(spin = s.copy(file = it.trim()))) })
            NumberBox("striped balls fed", s.balls?.toDouble(), { onChange(n.copy(spin = s.copy(balls = it?.toInt()))) })
            Hint("The machine's dials for this clip go under clip 8 in machine clips.")
            Spacer(Modifier.height(zpx(8f)))
        }

        SectionHeader("notes")
        TextBox("anything else: lens, shutter, battery, heat", n.chrisNote, { onChange(n.copy(chrisNote = it)) }, singleLine = false)

        SectionHeader("the file")
        FileRows(n, onShare, onClear)
    }
}

/** Share (at the top and the bottom of the form, so it's never far), and start afresh (bottom only). */
@Composable
private fun FileRows(n: FieldNotes, onShare: () -> Unit, onClear: (() -> Unit)?) {
    TextRow("share the file", "Sends ${n.session}.json: pick Drive and save it in the Tuesday folder", onClick = onShare)
    if (onClear != null) TextRow("start afresh", "Clears this sheet", onClick = onClear)
}

@Composable
private fun Hint(text: String) = TennisText(text, TennisTokens.Type.listSecondary)

@Composable
private fun ItemTitle(text: String) {
    TennisText(text, TennisTokens.Type.listPrimary)
    Spacer(Modifier.height(LocalZpx.current(TennisTokens.Measure.itemTitleGap)))
}

private fun metres(v: Double?) = v?.let { MiniJson.number(it, 3) + " m" } ?: "–"

/**
 * A number in a text box (decimal keyboard). What's typed is kept as typed ("3." stays "3.");
 * the box shows the value afresh when it changes from outside (a removed row, start afresh).
 */
@Composable
private fun NumberBox(label: String, value: Double?, onChange: (Double?) -> Unit, modifier: Modifier = Modifier) {
    var typed by remember { mutableStateOf(value?.let { MiniJson.number(it, 4) } ?: "") }
    fun parse(s: String) = s.trim().replace(',', '.').toDoubleOrNull()
    val p = parse(typed)
    val same = if (p == null || value == null) p == value else kotlin.math.abs(p - value) <= 1e-9 * maxOf(1.0, kotlin.math.abs(value))
    val shown = if (same) typed else value?.let { MiniJson.number(it, 4) } ?: ""
    TextBox(label, shown, { s -> typed = s; onChange(parse(s)) }, modifier, keyboard = KeyboardType.Decimal)
}
