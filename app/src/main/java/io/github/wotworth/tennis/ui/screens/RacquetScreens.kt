package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.data.Racquet
import io.github.wotworth.tennis.data.StringJob
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.components.GlyphTile
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.NumberTile
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.Sparkline
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.components.FitText
import io.github.wotworth.tennis.ui.motion.CategoryPagerState
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch

/** What a racquet's tiles show (NAV-02, RAC-03). */
data class RacquetView(
    val racquet: Racquet,
    val job: StringJob?,
    val hours: Double,
    val days: Long?,
    val feels: List<Int>,
    val trend: String?,
) {
    companion object {
        fun of(r: Racquet, d: AppData, today: Long = Now.day()): RacquetView {
            val job = Strings.currentJob(r.id, d.jobs)
            val feels = job?.let { Strings.feels(it, d.jobs, d.sessions) }.orEmpty()
            return RacquetView(r, job, job?.let { Strings.hours(it, d.jobs, d.sessions) } ?: 0.0, job?.let { today - it.date }, feels, Strings.feelTrend(feels))
        }
    }
}

@Composable private fun m(): Dp = LocalZpx.current(TennisTokens.Layout.tileMedium)
@Composable private fun s(): Dp = LocalZpx.current(TennisTokens.Layout.tileSmall)
@Composable private fun w(): Dp = LocalZpx.current(TennisTokens.Layout.tileMedium * 2 + TennisTokens.Layout.tileGap)
@Composable private fun gap(): Dp = LocalZpx.current(TennisTokens.Layout.tileGap)

// ---- the main "racquets" page (RAC-04, v0.4) -------------------------------------------------

/**
 * RAC-04 (v0.4): one wide tile per active racquet (name, strings, tension, hours on the
 * current strings), a "+ add racquet" tile at the end, and retired racquets as text rows below.
 * No limit; the page scrolls.
 */
@Composable
fun RacquetsPage() {
    val d = appData()
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    PivotColumn {
        ProposalTiles()
        if (d.loaded && d.racquets.isEmpty()) {
            TennisText("Add your racquets to start.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(12f)))
        }
        Column(verticalArrangement = Arrangement.spacedBy(gap())) {
            d.active.forEach { r -> RacquetTile(RacquetView.of(r, d)) { nav.open(Screen.Racquet(r.id)) } }
            GlyphTile("add racquet", R.drawable.fluent_add, m()) { nav.open(Screen.RacquetEdit()) }
        }
        if (d.retired.isNotEmpty()) {
            SectionHeader("retired")
            d.retired.forEach { r ->
                val jobs = Strings.jobsFor(r.id, d.jobs)
                val total = jobs.sumOf { Strings.hours(it, d.jobs, d.sessions) }
                TextRow(r.name, listOf(r.model, "${jobs.size} ${if (jobs.size == 1) "restring" else "restrings"}", "${Strings.hoursText(total)} h in all")
                    .filter { it.isNotBlank() }.joinToString(" · ")) { nav.open(Screen.Racquet(r.id)) }
            }
        }
    }
}

/** RAC-04: a racquet's wide tile: name and strings on the left, hours big on the right. */
@Composable
fun RacquetTile(v: RacquetView, onClick: () -> Unit) {
    val zpx = LocalZpx.current
    val job = v.job
    val lines = buildList {
        add(v.racquet.name)
        add(job?.let { Strings.setupText(it) } ?: "no strings logged yet")
        job?.let { add("${Strings.tensionText(it)} lb") }
    }
    Tile("hours on strings", w(), m(), description = "${v.racquet.name}, ${Strings.hoursText(v.hours)} hours on strings", onClick = onClick,
        background = job?.let { photoBackground(it) }) {
        Column(Modifier.align(Alignment.TopStart).padding(end = zpx(TennisTokens.Layout.tileMedium * 0.55f))) {
            TennisText(lines[0], TennisTokens.Type.tileTextLarge, maxLines = 1)
            Spacer(Modifier.height(zpx(4f)))
            lines.drop(1).forEach { TennisText(it, TennisTokens.Type.tileText, maxLines = 2) }
        }
        Column(Modifier.align(Alignment.TopEnd).width(zpx(TennisTokens.Layout.tileMedium * 0.5f)), horizontalAlignment = Alignment.End) {
            FitText(Strings.hoursText(v.hours), TennisTokens.Type.tileNumber)
        }
    }
}

// ---- one racquet's pivot (v0.4) --------------------------------------------------------------

val RACQUET_PIVOTS = listOf("strings", "history", "sessions")
const val R_STRINGS = 0
const val R_HISTORY = 1
const val R_SESSIONS = 2

/**
 * v0.4: a racquet's own pivot, its name as the small title: strings (the current setup, in the
 * chosen tile layout), history (its restrings) and sessions (only those with this racquet). Its
 * "…" menu edits, retires (or brings back) and deletes it, and opens settings.
 */
@Composable
fun RacquetHubScreen(id: Long, initial: Int) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    if (!d.loaded) return
    val r = d.racquet(id) ?: run { TennisText("This racquet was deleted.", TennisTokens.Type.listPrimary); return }
    // The stats page's feel chart follows the racquet opened last.
    if (app.prefs.selectedRacquet != r.id) app.prefs.selectRacquet(r.id)
    PivotScreen(
        r.name, RACQUET_PIVOTS, initial,
        onChange = { i -> nav.stack[nav.stack.lastIndex] = Screen.Racquet(id, i) },
        bar = { p ->
            when (p.selected) {
                R_HISTORY -> listOf(BarButton(R.drawable.fluent_arrow_sync, "restrung", !r.retired) { nav.open(Screen.RestringEdit(r.id)) })
                R_SESSIONS -> listOf(BarButton(R.drawable.fluent_add, "log session", !r.retired) { nav.open(Screen.SessionEdit(racquetId = r.id)) })
                else -> emptyList()
            }
        },
        onMore = {
            o.menu(*buildList<Pair<String, () -> Unit>> {
                add("edit racquet" to { nav.open(Screen.RacquetEdit(r.id)) })
                if (r.retired) add("bring back racquet" to { scope.launch { app.repo.saveRacquet(r.copy(retired = false)) }; Unit })
                else add("retire racquet" to {
                    o.confirm("retire ${r.name}?", "It leaves the racquets page. Its restrings and sessions are kept, under \"retired\".", "retire") {
                        scope.launch { app.repo.saveRacquet(r.copy(retired = true)); nav.back() }
                    }
                })
                add("delete racquet" to {
                    o.confirm("delete ${r.name}?", "Its restrings go too; its sessions stay, without a racquet. Retire it instead to keep its history.", "delete") {
                        scope.launch { app.repo.deleteRacquet(r); nav.back() }
                    }
                })
                add("settings" to { nav.open(Screen.Settings) })
            }.toTypedArray())
        },
    ) { i, pager ->
        val v = RacquetView.of(r, d)
        when (i) {
            R_STRINGS -> RacquetStringsPage(v, pager)
            R_HISTORY -> RacquetHistoryPage(r, d)
            R_SESSIONS -> RacquetSessionsPage(r, d)
        }
    }
}

@Composable
private fun RacquetStringsPage(v: RacquetView, pager: CategoryPagerState) {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    PivotColumn {
        ProposalTiles()
        val desc = listOf(v.racquet.model, v.racquet.colour).filter { it.isNotBlank() }.joinToString(" · ")
        if (desc.isNotBlank() || v.racquet.retired) {
            TennisText(listOf(desc, if (v.racquet.retired) "retired" else "").filter { it.isNotBlank() }.joinToString(" · "), TennisTokens.Type.listSecondary)
            Spacer(Modifier.height(zpx(12f)))
        }
        when (app.prefs.stringsLayout) {
            2 -> LayoutHero(v, pager)
            3 -> LayoutMixed(v, pager)
            else -> LayoutGrid(v, pager)
        }
    }
}

/** v0.4: this racquet's restrings, newest first. */
@Composable
private fun RacquetHistoryPage(r: Racquet, d: AppData) {
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    val zpx = LocalZpx.current
    PivotColumn {
        val jobs = Strings.jobsFor(r.id, d.jobs)
        if (jobs.isEmpty()) {
            TennisText("No restrings logged.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Tap the circular arrows below to log the strings in it now.", TennisTokens.Type.listSecondary)
        }
        jobs.forEach { j ->
            val hours = Strings.hoursText(Strings.hours(j, d.jobs, d.sessions))
            TextRow(
                "${Strings.shortDayText(j.date, Now.day())} · ${Strings.tensionText(j)} lb",
                listOf(Strings.setupText(j), j.shop, Strings.money(j.priceCents), "$hours h").filter { it.isNotBlank() }.joinToString(" · "),
                onLongClick = {
                    o.menu(
                        "shop order" to { nav.open(Screen.ShopOrder(j.id)) },
                        "edit" to { nav.open(Screen.RestringEdit(r.id, j.id)) },
                        "delete" to { o.confirm("delete restring?", Strings.setupText(j), "delete") { scope.launch { app.repo.deleteJob(j) } } },
                    )
                },
            ) { nav.open(Screen.RestringEdit(r.id, j.id)) }
        }
    }
}

/** v0.4: only the sessions played with this racquet. */
@Composable
private fun RacquetSessionsPage(r: Racquet, d: AppData) {
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    PivotColumn {
        val mine = d.sessions.filter { r.id in it.racquetIds }
        if (mine.isEmpty()) {
            TennisText("No sessions with this racquet yet.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
        }
        mine.forEach { s -> TextRow(sessionTitle(s), sessionDetail(s, d, withRacquet = false)) { nav.open(Screen.SessionEdit(s.session.id)) } }
    }
}

// ---- the strings page's tiles (NAV-02) ---------------------------------------------------------

private class TileSet(val v: RacquetView, val pager: CategoryPagerState, val nav: Navigator) {
    val job = v.job
    val hours = Strings.hoursText(v.hours)
    val tension = job?.let { Strings.tensionText(it) } ?: "–"
    val tensionLabel = if (job != null && job.crossesLb != null && job.crossesLb != job.mainsLb) "lb main/cross" else "lb"
    val days = v.days?.toString() ?: "–"
    val daysLabel = if (v.days == 1L) "day strung" else "days strung"
    val feel = if (v.feels.isEmpty()) "–" else "%.1f".format(java.util.Locale.US, v.feels.takeLast(3).average())
    val feelLabel = when (v.trend) { null -> if (v.feels.isEmpty()) "no feel ratings" else "feel"; else -> "feel, ${v.trend}" }
    val live = !v.racquet.retired
    fun logSession() { if (live) nav.open(Screen.SessionEdit(racquetId = v.racquet.id)) }
    fun restrung() { if (live) nav.open(Screen.RestringEdit(v.racquet.id)) }
    fun order() { job?.let { nav.open(Screen.ShopOrder(it.id)) } ?: restrung() }
    fun sessions() = pager.select(R_SESSIONS)
}

@Composable
private fun tiles(v: RacquetView, pager: CategoryPagerState) = TileSet(v, pager, LocalNav.current)

@Composable
private fun HoursTile(t: TileSet, width: Dp, height: Dp, withSparkline: Boolean = false) {
    val zpx = LocalZpx.current
    NumberTile(t.hours, "hours on strings", width, height, onClick = { t.sessions() }) {
        if (withSparkline && t.v.feels.size >= 2) {
            Sparkline(t.v.feels, Modifier.align(Alignment.TopEnd).padding(top = zpx(10f)).width(width * 0.42f).height(height * 0.42f))
        }
    }
}

@Composable private fun TensionTile(t: TileSet, small: Boolean = false) =
    NumberTile(t.tension, t.tensionLabel, if (small) s() else m(), if (small) s() else m(), small = small, onClick = { t.order() })

@Composable private fun DaysTile(t: TileSet, small: Boolean = false) =
    NumberTile(t.days, if (small) "days" else t.daysLabel, if (small) s() else m(), if (small) s() else m(), small = small, onClick = { t.order() })

@Composable
private fun FeelTile(t: TileSet, small: Boolean = false, wide: Boolean = false) {
    val zpx = LocalZpx.current
    val width = if (wide) w() else if (small) s() else m()
    val height = if (small) s() else m()
    NumberTile(t.feel, if (small) "feel" else t.feelLabel, width, height, small = small, onClick = { t.sessions() }) {
        if (!small && t.v.feels.size >= 2) {
            if (wide) Sparkline(t.v.feels, Modifier.align(Alignment.TopEnd).padding(top = zpx(12f), end = zpx(2f)).width(width * 0.55f).height(height * 0.3f))
            else Sparkline(t.v.feels, Modifier.align(Alignment.BottomStart).padding(bottom = zpx(22f)).fillMaxWidth().height(height * 0.2f))
        }
    }
}

/** NAV-02: the wide setup tile: strings, gauges, hybrid; the package photo behind it (PH-4). */
@Composable
private fun SetupTile(t: TileSet, withTension: Boolean = false) {
    val job = t.job
    if (job == null) {
        Tile("current setup", w(), m(), onClick = { t.restrung() }) { TileLines(listOf("No strings logged yet", if (t.live) "Tap to log the strings in it" else "")) }
        return
    }
    val lines = buildList {
        add(if (job.hybrid) "${job.mains.name.ifBlank { "mains" }} ${job.mains.gauge}".trim() else Strings.setupText(job))
        if (job.hybrid) add("× ${job.crossesOwn.name.ifBlank { "crosses" }} ${job.crossesOwn.gauge}".trim())
        else if (job.mains.material.isNotBlank()) add(job.mains.material)
        if (withTension) add("${Strings.tensionText(job)} lb")
    }
    val label = (if (job.hybrid) "hybrid · " else "") + "strung " + Strings.shortDayText(job.date, Now.day())
    Tile(label, w(), m(), description = "current setup", onClick = { t.order() }, background = photoBackground(job)) { TileLines(lines) }
}

/** NAV-02: the mains package photo behind a tile (PH-4). */
@Composable
internal fun photoBackground(job: StringJob): (@Composable androidx.compose.foundation.layout.BoxScope.() -> Unit)? = PhotoBehind(job.mainsPhoto)

@Composable
private fun LogSmall(t: TileSet) = GlyphTile("log session", R.drawable.fluent_timer, s(), showLabel = false) { t.logSession() }
@Composable
private fun RestrungSmall(t: TileSet) = GlyphTile("restrung", R.drawable.fluent_arrow_sync, s(), showLabel = false) { t.restrung() }

/** PHO-01: the camera tile: a new restring for this racquet, starting with the package photo. */
@Composable
private fun CameraSmall(t: TileSet) {
    val nav = LocalNav.current
    GlyphTile("camera", R.drawable.fluent_camera, s(), showLabel = false) { if (t.live) nav.open(Screen.RestringEdit(t.v.racquet.id, camera = true)) }
}

/** Layout 1, "grid": two rows of medium number tiles, the wide setup tile, small actions. */
@Composable
private fun LayoutGrid(v: RacquetView, pager: CategoryPagerState) {
    val t = tiles(v, pager)
    Column(verticalArrangement = Arrangement.spacedBy(gap())) {
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) { HoursTile(t, m(), m()); TensionTile(t) }
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) { DaysTile(t); FeelTile(t) }
        SetupTile(t)
        if (t.live) Row(horizontalArrangement = Arrangement.spacedBy(gap())) { LogSmall(t); RestrungSmall(t); CameraSmall(t) }
    }
}

/** Layout 2, "hero": one wide hours tile with the feel line on it, then setup, then the rest. */
@Composable
private fun LayoutHero(v: RacquetView, pager: CategoryPagerState) {
    val t = tiles(v, pager)
    Column(verticalArrangement = Arrangement.spacedBy(gap())) {
        HoursTile(t, w(), m(), withSparkline = true)
        SetupTile(t)
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) {
            TensionTile(t)
            Column(verticalArrangement = Arrangement.spacedBy(gap())) {
                Row(horizontalArrangement = Arrangement.spacedBy(gap())) { DaysTile(t, small = true); FeelTile(t, small = true) }
                if (t.live) Row(horizontalArrangement = Arrangement.spacedBy(gap())) { LogSmall(t); RestrungSmall(t) }
            }
        }
        if (t.live) CameraSmall(t)
    }
}

/** Layout 3, "mixed": setup with tension on top, hours beside a block of small tiles, feel wide. */
@Composable
private fun LayoutMixed(v: RacquetView, pager: CategoryPagerState) {
    val t = tiles(v, pager)
    Column(verticalArrangement = Arrangement.spacedBy(gap())) {
        SetupTile(t, withTension = true)
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) {
            HoursTile(t, m(), m())
            Column(verticalArrangement = Arrangement.spacedBy(gap())) {
                if (t.live) Row(horizontalArrangement = Arrangement.spacedBy(gap())) { LogSmall(t); RestrungSmall(t) }
                Row(horizontalArrangement = Arrangement.spacedBy(gap())) { DaysTile(t, small = true); if (t.live) CameraSmall(t) else FeelTile(t, small = true) }
            }
        }
        if (v.feels.isNotEmpty()) FeelTile(t, wide = true)
    }
}
