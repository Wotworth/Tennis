package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.input.KeyboardType
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.data.Cue
import io.github.wotworth.tennis.data.Racquet
import io.github.wotworth.tennis.data.Session
import io.github.wotworth.tennis.data.StringItem
import io.github.wotworth.tennis.data.StringJob
import io.github.wotworth.tennis.data.StringSpec
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.DateField
import io.github.wotworth.tennis.ui.components.FieldLabel
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.ToggleSwitch
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch

/** STR-02: materials offered as you type. */
val MATERIALS = listOf("polyester", "co-poly", "multifilament", "synthetic gut", "natural gut", "Kevlar/aramid", "hybrid-other")
/** CUE-01: headings offered as you type. */
val HEADINGS = listOf("forehand", "backhand", "serve", "volley", "return", "footwork", "mental")

// ---- racquets (RAC-01) ----------------------------------------------------------------------

@Composable
fun RacquetEditScreen(id: Long?) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val old = id?.let { d.racquet(it) }
    var name by remember(old) { mutableStateOf(old?.name ?: "") }
    var model by remember(old) { mutableStateOf(old?.model ?: "") }
    var colour by remember(old) { mutableStateOf(old?.colour ?: "") }
    val ok = name.isNotBlank()
    Page(if (old == null) "new racquet" else "racquet", bar = listOf(
        BarButton(R.drawable.fluent_checkmark, "save", ok) {
            scope.launch {
                val newId = app.repo.saveRacquet((old ?: Racquet(name = "")).copy(name = name.trim(), model = model.trim(), colour = colour.trim()))
                if (old == null) app.prefs.selectRacquet(newId)
                nav.back()
            }
        },
        BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() },
    )) {
        TextBox("name", name, { name = it }, suggestions = emptyList())
        TextBox("model", model, { model = it }, suggestions = d.racquets.map { it.model })
        TextBox("colour", colour, { colour = it }, suggestions = d.racquets.map { it.colour })
        TennisText("For example: Black Blade #1, Wilson Blade 98 v9, black.", TennisTokens.Type.listSecondary)
    }
}

// ---- restrings (STR-01 to STR-04, RAC-02) ---------------------------------------------------

@Composable
fun RestringEditScreen(racquetId: Long, jobId: Long?) {
    val d = appData()
    if (!d.loaded) return
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    val editing = jobId?.let { id -> d.jobs.firstOrNull { it.id == id } }
    // STR-03: a new job starts from this racquet's last job, else the last job on any racquet.
    val base = editing ?: (Strings.currentJob(racquetId, d.jobs) ?: d.jobs.firstOrNull())?.copy(id = 0, racquetId = racquetId, date = Now.day(), notes = "", mainsPhoto = null, crossesPhoto = null)
        ?: StringJob(racquetId = racquetId, date = Now.day())
    var j by remember(base.id, base.racquetId, d.jobs.size) { mutableStateOf(base) }
    var price by remember(base.id, d.jobs.size) { mutableStateOf(base.priceCents?.let { Strings.money(it).removePrefix("$") } ?: "") }
    var mainsLb by remember(base.id, d.jobs.size) { mutableStateOf(base.mainsLb?.let { Strings.lb(it) } ?: "") }
    var crossesLb by remember(base.id, d.jobs.size) { mutableStateOf(base.crossesLb?.let { Strings.lb(it) } ?: "") }
    val all = d.jobs
    fun sugg(f: (StringSpec) -> String) = (all.map { f(it.mains) } + all.map { f(it.crossesOwn) } + d.strings.map { f(it.spec) }).filter { it.isNotBlank() }.distinct()
    val ok = mainsLb.isEmpty() || mainsLb.toDoubleOrNull() != null
    Page(if (editing == null) "restrung" else "restring", bar = buildList {
        add(BarButton(R.drawable.fluent_checkmark, "save", ok) {
            scope.launch {
                val cross = crossesLb.toDoubleOrNull() ?: mainsLb.toDoubleOrNull()
                app.repo.saveJob(j.copy(mainsLb = mainsLb.toDoubleOrNull(), crossesLb = cross, priceCents = Strings.parseMoney(price),
                    shop = j.shop.trim(), mains = j.mains.trimmed(), crossesOwn = j.crossesOwn.trimmed()))
                app.prefs.selectRacquet(j.racquetId)
                nav.back()
            }
        })
        add(BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() })
        if (editing != null) {
            add(BarButton(R.drawable.fluent_receipt, "shop order") { nav.open(Screen.ShopOrder(editing.id)) })
            add(BarButton(R.drawable.fluent_delete, "delete") { o.confirm("delete restring?", Strings.setupText(editing), "delete") { scope.launch { app.repo.deleteJob(editing); nav.back() } } })
        }
    }) {
        if (d.racquets.size > 1) ChoiceRow("racquet", d.racquets.map { it.id to it.name }, setOf(j.racquetId), { j = j.copy(racquetId = it) })
        DateField("date strung", j.date, { j = j.copy(date = it) })
        PhotoSlots.content?.invoke(j) { j = it }
        SectionHeader(if (j.hybrid) "mains" else "strings")
        SpecFields(j.mains, base.mains, editing == null, ::sugg) { j = j.copy(mains = it) }
        ToggleSwitch("hybrid (different crosses)", j.hybrid) { j = j.copy(hybrid = it) }
        if (j.hybrid) {
            SectionHeader("crosses")
            SpecFields(j.crossesOwn, base.crossesOwn, editing == null, ::sugg) { j = j.copy(crossesOwn = it) }
        }
        SectionHeader("tension (lb)")
        Row(horizontalArrangement = Arrangement.spacedBy(LocalZpx.current(12f))) {
            Column(Modifier.weight(1f)) { TextBox(changed("mains", mainsLb, base.mainsLb?.let { Strings.lb(it) } ?: "", editing == null), mainsLb, { mainsLb = it }, keyboard = KeyboardType.Decimal) }
            Column(Modifier.weight(1f)) { TextBox(changed("crosses", crossesLb, base.crossesLb?.let { Strings.lb(it) } ?: "", editing == null), crossesLb, { crossesLb = it }, keyboard = KeyboardType.Decimal) }
        }
        TextBox(changed("shop", j.shop, base.shop, editing == null), j.shop, { j = j.copy(shop = it) }, suggestions = all.map { it.shop })
        TextBox(changed("price ($)", price, base.priceCents?.let { Strings.money(it).removePrefix("$") } ?: "", editing == null), price, { price = it }, keyboard = KeyboardType.Decimal)
        TextBox("notes", j.notes, { j = j.copy(notes = it) }, singleLine = false)
    }
}

/** STR-03: a field changed from the pre-filled job is marked in its label until saved. */
private fun changed(label: String, now: String, was: String, isNew: Boolean) = if (isNew && now.trim() != was.trim()) "$label · changed" else label

private fun StringSpec.trimmed() = StringSpec(brand.trim(), model.trim(), gauge.trim(), material.trim())

@Composable
private fun SpecFields(s: StringSpec, was: StringSpec, isNew: Boolean, sugg: ((StringSpec) -> String) -> List<String>, onChange: (StringSpec) -> Unit) {
    TextBox(changed("brand", s.brand, was.brand, isNew), s.brand, { onChange(s.copy(brand = it)) }, suggestions = sugg { it.brand })
    TextBox(changed("model", s.model, was.model, isNew), s.model, { onChange(s.copy(model = it)) }, suggestions = sugg { it.model })
    Row(horizontalArrangement = Arrangement.spacedBy(LocalZpx.current(12f))) {
        Column(Modifier.weight(1f)) { TextBox(changed("gauge", s.gauge, was.gauge, isNew), s.gauge, { onChange(s.copy(gauge = it)) }, suggestions = sugg { it.gauge }) }
        Column(Modifier.weight(1.4f)) { TextBox(changed("material", s.material, was.material, isNew), s.material, { onChange(s.copy(material = it)) }, suggestions = (MATERIALS + sugg { it.material }).distinct()) }
    }
}

/** PH-4 adds the package photos here (PHO-01, PHO-02). */
object PhotoSlots { var content: (@Composable (StringJob, (StringJob) -> Unit) -> Unit)? = null }

// ---- sessions (SES-01, SES-02, SES-05, RAC-05) ----------------------------------------------

@Composable
fun SessionEditScreen(id: Long?, proposalId: Long?) {
    val d = appData()
    if (!d.loaded) return
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    val zpx = LocalZpx.current
    val editing = id?.let { sid -> d.sessions.firstOrNull { it.session.id == sid } }
    val proposal = proposalId?.let { pid -> d.proposals.firstOrNull { it.id == pid } }
    val defaultRacquets = app.prefs.lastRacquets.filter { d.racquet(it) != null }.ifEmpty { listOfNotNull((d.racquet(app.prefs.selectedRacquet) ?: d.racquets.firstOrNull())?.id) }
    val base = editing?.session ?: proposal?.let { p ->
        val zone = java.time.ZoneId.systemDefault()
        Session(date = java.time.Instant.ofEpochMilli(p.startMillis).atZone(zone).toLocalDate().toEpochDay(), minutes = ((p.endMillis - p.startMillis) / 60000).toInt(),
            source = p.source, startMillis = p.startMillis, endMillis = p.endMillis, avgHr = p.avgHr, maxHr = p.maxHr, steps = p.steps)
    } ?: Session(date = Now.day(), minutes = TennisTokens.Sessions.defaultMinutes)
    var s by remember(base) { mutableStateOf(base) }
    var racquets by remember(base) { mutableStateOf(editing?.racquetIds ?: defaultRacquets) }
    val ok = s.minutes > 0 && (racquets.isNotEmpty() || d.racquets.isEmpty())
    Page(if (proposal != null) "you played" else if (editing == null) "new session" else "session", bar = buildList {
        add(BarButton(R.drawable.fluent_checkmark, "save", ok) {
            scope.launch {
                app.repo.saveSession(s, racquets)
                app.prefs.rememberLastRacquets(racquets)
                proposal?.let { app.repo.setProposalState(it.id, "accepted") }
                nav.back()
            }
        })
        add(BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() })
        if (editing != null) add(BarButton(R.drawable.fluent_delete, "delete") {
            o.confirm("delete session?", sessionTitle(editing), "delete") { scope.launch { app.repo.deleteSession(editing.session.id); nav.back() } }
        })
    }) {
        if (proposal != null) {
            TennisText(windowText(proposal), TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(4f)))
            TennisText(listOfNotNull(proposal.avgHr?.let { "$it avg bpm" }, proposal.maxHr?.let { "$it max" }, proposal.steps?.let { "$it steps" }).joinToString(" · "), TennisTokens.Type.listSecondary)
            Spacer(Modifier.height(zpx(14f)))
        } else DateField("date", s.date, { s = s.copy(date = it) })
        // RAC-05: which racquets, more than one allowed.
        if (d.racquets.isEmpty()) {
            TennisText("Add a racquet on the strings page to count hours on its strings.", TennisTokens.Type.listSecondary)
            Spacer(Modifier.height(zpx(12f)))
        } else ChoiceRow("racquet (tap all you used)", d.racquets.map { it.id to it.name }, racquets.toSet(), { r ->
            racquets = if (r in racquets) racquets - r else racquets + r
        })
        FieldLabel("how long")
        TennisText(Strings.minutesText(s.minutes), TennisTokens.Type.listPrimary)
        Spacer(Modifier.height(zpx(4f)))
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(18f))) {
            TennisTokens.Sessions.presets.forEach { m -> SmallAction(Strings.minutesText(m)) { s = s.copy(minutes = m) } }
            SmallAction("−15") { s = s.copy(minutes = (s.minutes - 15).coerceAtLeast(15)) }
            SmallAction("+15") { s = s.copy(minutes = s.minutes + 15) }
        }
        Spacer(Modifier.height(zpx(14f)))
        ChoiceRow("how the strings felt (optional)", (1..5).map { it to "$it" }, setOfNotNull(s.feel), { f -> s = s.copy(feel = if (s.feel == f) null else f) })
        TextBox("notes", s.notes, { s = s.copy(notes = it) }, singleLine = false)
    }
}

// ---- the proposal prompt (DET-30) ---------------------------------------------------------------

@Composable
fun ProposalScreen(id: Long) {
    val d = appData()
    if (!d.loaded) return
    val p = d.proposals.firstOrNull { it.id == id }
    val app = LocalApp.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val zpx = LocalZpx.current
    Page("tennis?") {
        if (p == null || p.state != "waiting") {
            TennisText("Already answered.", TennisTokens.Type.listPrimary)
            return@Page
        }
        TennisText("Did you play tennis?", TennisTokens.Type.warmupCue)
        Spacer(Modifier.height(zpx(10f)))
        TennisText(windowText(p), TennisTokens.Type.listPrimary)
        Spacer(Modifier.height(zpx(4f)))
        TennisText(listOfNotNull(Strings.minutesText(((p.endMillis - p.startMillis) / 60000).toInt()), p.avgHr?.let { "$it avg bpm" }, p.maxHr?.let { "$it max" }, p.steps?.let { "$it steps" },
            if (p.source == "workout") "from a Fitbit workout" else "from your heart rate").joinToString(" · "), TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(20f)))
        val size = zpx(TennisTokens.Layout.tileMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(TennisTokens.Layout.tileGap))) {
            io.github.wotworth.tennis.ui.components.GlyphTile("yes", R.drawable.fluent_checkmark, size) {
                // Yes: the session page, filled in, asks for the racquets and the feel (RAC-05).
                nav.back(); nav.open(Screen.SessionEdit(proposalId = p.id))
            }
            io.github.wotworth.tennis.ui.components.GlyphTile("no", R.drawable.fluent_dismiss, size) {
                scope.launch { app.repo.setProposalState(p.id, "rejected"); nav.back() }
            }
        }
    }
}

// ---- shop order (STR-20) --------------------------------------------------------------------

@Composable
fun ShopOrderScreen(jobId: Long) {
    val d = appData()
    val view = LocalView.current
    DisposableEffect(Unit) { view.keepScreenOn = true; onDispose { view.keepScreenOn = false } }
    val j = d.jobs.firstOrNull { it.id == jobId } ?: return
    val zpx = LocalZpx.current
    Page("shop order") {
        d.racquet(j.racquetId)?.let { r ->
            TennisText(listOf(r.name, r.model).filter { it.isNotBlank() }.joinToString(" · "), TennisTokens.Type.listSecondary)
            Spacer(Modifier.height(zpx(14f)))
        }
        @Composable fun block(title: String, s: StringSpec, lb: Double?) {
            TennisText(title, TennisTokens.Type.sectionHeader)
            Spacer(Modifier.height(zpx(4f)))
            TennisText(s.name.ifBlank { "–" }, TennisTokens.Type.orderValue)
            Spacer(Modifier.height(zpx(4f)))
            TennisText(listOf(s.gauge, s.material).filter { it.isNotBlank() }.joinToString(" · ").ifBlank { " " }, TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(4f)))
            TennisText("${Strings.lb(lb)} lb", TennisTokens.Type.orderValue)
            Spacer(Modifier.height(zpx(20f)))
        }
        block("mains", j.mains, j.mainsLb)
        block("crosses", j.crosses, j.crossesLb ?: j.mainsLb)
        if (j.notes.isNotBlank()) TennisText(j.notes, TennisTokens.Type.listPrimary)
    }
}

// ---- cues (CUE-01, CUE-02) ---------------------------------------------------------------------

@Composable
fun CueEditScreen(id: Long?) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    val old = id?.let { cid -> d.cues.firstOrNull { it.id == cid } }
    var heading by remember(old) { mutableStateOf(old?.heading ?: "") }
    var text by remember(old) { mutableStateOf(old?.text ?: "") }
    var pinned by remember(old) { mutableStateOf(old?.pinned ?: true) }
    Page(if (old == null) "new cue" else "cue", bar = buildList {
        add(BarButton(R.drawable.fluent_checkmark, "save", text.isNotBlank()) {
            scope.launch { app.repo.saveCue((old ?: Cue(heading = "", text = "")).copy(heading = heading.trim().lowercase(), text = text.trim(), pinned = pinned)); nav.back() }
        })
        add(BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() })
        if (old != null) add(BarButton(R.drawable.fluent_delete, "delete") { o.confirm("delete cue?", old.text, "delete") { scope.launch { app.repo.deleteCue(old); nav.back() } } })
    }) {
        TextBox("stroke", heading, { heading = it }, suggestions = (HEADINGS + d.cues.map { it.heading }).distinct(), maxSuggestions = 7)
        TextBox("cue", text, { text = it }, singleLine = false)
        ToggleSwitch("pin to warmup", pinned) { pinned = it }
    }
}

// ---- strings (STR-30) ------------------------------------------------------------------------

@Composable
fun StringEditScreen(id: Long?) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val old = id?.let { sid -> d.strings.firstOrNull { it.id == sid } }
    var spec by remember(old) { mutableStateOf(old?.spec ?: StringSpec()) }
    var notes by remember(old) { mutableStateOf(old?.notes ?: "") }
    fun sugg(f: (StringSpec) -> String) = (d.strings.map { f(it.spec) } + d.jobs.map { f(it.mains) }).filter { it.isNotBlank() }.distinct()
    Page(if (old == null) "new string" else "string", bar = listOf(
        BarButton(R.drawable.fluent_checkmark, "save", spec.brand.isNotBlank() || spec.model.isNotBlank()) {
            scope.launch { app.repo.saveString((old ?: StringItem(spec = spec)).copy(spec = spec.trimmed(), notes = notes.trim())); nav.back() }
        },
        BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() },
    )) {
        StringPhoto.content?.invoke(old?.photo)
        SpecFields(spec, spec, false, ::sugg) { spec = it }
        TextBox("notes", notes, { notes = it }, singleLine = false)
    }
}

object StringPhoto { var content: (@Composable (String?) -> Unit)? = null }
