package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
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
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.GlyphTile
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.NumberTile
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.Sparkline
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.motion.CategoryPagerState
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.textStyleFor
import kotlinx.coroutines.launch

/** What the strings page shows for one racquet (NAV-02, RAC-03). */
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

/**
 * NAV-02 (v0.3): the racquet switcher (one tap), tiles with real numbers in mixed sizes, and the
 * racquet's recent restrings as Zune text rows. Three tile layouts, chosen in settings, for Chris
 * to pick from (Chris, 5 Nov).
 */
@Composable
fun StringsPage(pager: CategoryPagerState) {
    val data = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    PivotColumn {
        ProposalTiles()
        if (data.loaded && data.racquets.isEmpty()) {
            TennisText("Add your racquets to start.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(12f)))
            GlyphTile("add racquet", R.drawable.fluent_add, zpx(TennisTokens.Layout.tileMedium)) { nav.open(Screen.RacquetEdit()) }
            return@PivotColumn
        }
        if (data.racquets.isEmpty()) return@PivotColumn
        val selected = data.racquet(app.prefs.selectedRacquet) ?: data.racquets.first()
        RacquetSwitcher(data.racquets, selected)
        Spacer(Modifier.height(zpx(12f)))
        val v = RacquetView.of(selected, data)
        when (app.prefs.stringsLayout) {
            2 -> LayoutHero(v, pager)
            3 -> LayoutMixed(v, pager)
            else -> LayoutGrid(v, pager)
        }
        RestringList(selected, data)
    }
}

/** RAC-04: the racquets as a row of names; tap switches, long-press edits; "+" adds one. */
@Composable
private fun RacquetSwitcher(racquets: List<Racquet>, selected: Racquet) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(zpx(16f)), verticalAlignment = Alignment.Bottom) {
        val style = textStyleFor(TennisTokens.Type.racquetName)
        racquets.forEach { r ->
            BasicText(
                r.name,
                style = style.copy(color = if (r.id == selected.id) TennisTokens.Colors.primary else TennisTokens.Colors.disabled),
                maxLines = 1,
                modifier = Modifier.press(description = r.name, onLongClick = {
                    o.menu(
                        "edit racquet" to { nav.open(Screen.RacquetEdit(r.id)) },
                        "delete racquet" to { o.confirm("delete ${r.name}?", "Its restrings go too. Sessions stay, without this racquet.", "delete") { scope.launch { app.repo.deleteRacquet(r) } } },
                    )
                }) { app.prefs.selectRacquet(r.id) },
            )
        }
        BasicText("+", style = style.copy(color = TennisTokens.Colors.disabled), modifier = Modifier.press(description = "add racquet") { nav.open(Screen.RacquetEdit()) })
    }
    if (selected.model.isNotBlank() || selected.colour.isNotBlank()) {
        Spacer(Modifier.height(zpx(2f)))
        TennisText(listOf(selected.model, selected.colour).filter { it.isNotBlank() }.joinToString(" · "), TennisTokens.Type.listSecondary)
    }
}

// ---- the tiles -------------------------------------------------------------------------------

private class TileSet(val v: RacquetView, val pager: CategoryPagerState, val nav: io.github.wotworth.tennis.ui.Navigator) {
    val job = v.job
    val hours = Strings.hoursText(v.hours)
    val tension = job?.let { Strings.tensionText(it) } ?: "–"
    val tensionLabel = if (job != null && job.crossesLb != null && job.crossesLb != job.mainsLb) "lb main/cross" else "lb"
    val days = v.days?.toString() ?: "–"
    val daysLabel = if (v.days == 1L) "day strung" else "days strung"
    val feel = if (v.feels.isEmpty()) "–" else "%.1f".format(java.util.Locale.US, v.feels.takeLast(3).average())
    val feelLabel = when (v.trend) { null -> if (v.feels.isEmpty()) "no feel ratings" else "feel"; else -> "feel, ${v.trend}" }
    fun logSession() = nav.open(Screen.SessionEdit())
    fun restrung() = nav.open(Screen.RestringEdit(v.racquet.id))
    fun order() { job?.let { nav.open(Screen.ShopOrder(it.id)) } ?: restrung() }
}

@Composable
private fun tiles(v: RacquetView, pager: CategoryPagerState) = TileSet(v, pager, LocalNav.current)

@Composable private fun m(): Dp = LocalZpx.current(TennisTokens.Layout.tileMedium)
@Composable private fun s(): Dp = LocalZpx.current(TennisTokens.Layout.tileSmall)
@Composable private fun w(): Dp = LocalZpx.current(TennisTokens.Layout.tileMedium * 2 + TennisTokens.Layout.tileGap)
@Composable private fun gap(): Dp = LocalZpx.current(TennisTokens.Layout.tileGap)

@Composable
private fun HoursTile(t: TileSet, width: Dp, height: Dp, withSparkline: Boolean = false) {
    val zpx = LocalZpx.current
    NumberTile(t.hours, "hours on strings", width, height, onClick = { t.pager.select(SESSIONS) }) {
        if (withSparkline && t.v.feels.size >= 2) {
            Sparkline(t.v.feels, Modifier.align(Alignment.TopEnd).padding(top = zpx(10f)).width(width * 0.42f).height(height * 0.42f))
        }
    }
}

@Composable private fun TensionTile(t: TileSet, small: Boolean = false) =
    NumberTile(t.tension, t.tensionLabel, if (small) s() else m(), if (small) s() else m(), small = small, onClick = { t.order() })

@Composable private fun DaysTile(t: TileSet, small: Boolean = false) =
    NumberTile(t.days, if (small) "days" else t.daysLabel, if (small) s() else m(), if (small) s() else m(), small = small, onClick = { t.restrung() })

@Composable
private fun FeelTile(t: TileSet, small: Boolean = false, wide: Boolean = false) {
    val zpx = LocalZpx.current
    val width = if (wide) w() else if (small) s() else m()
    val height = if (small) s() else m()
    NumberTile(t.feel, if (small) "feel" else t.feelLabel, width, height, small = small, onClick = { t.pager.select(STATS) }) {
        if (!small && t.v.feels.size >= 2) {
            if (wide) Sparkline(t.v.feels, Modifier.align(Alignment.TopEnd).padding(top = zpx(12f), end = zpx(2f)).width(width * 0.55f).height(height * 0.3f))
            else Sparkline(t.v.feels, Modifier.align(Alignment.BottomStart).padding(bottom = zpx(22f)).fillMaxWidth().height(height * 0.2f))
        }
    }
}

/** NAV-02: the wide setup tile: strings, gauges, hybrid. PH-4 puts the package photo behind it. */
@Composable
private fun SetupTile(t: TileSet, withTension: Boolean = false) {
    val job = t.job
    if (job == null) {
        Tile("current setup", w(), m(), onClick = { t.restrung() }) { TileLines(listOf("No strings logged yet", "Tap to log the last restring")) }
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

/** NAV-02: the mains package photo behind the setup tile (PH-4). */
@Composable
internal fun photoBackground(job: StringJob): (@Composable androidx.compose.foundation.layout.BoxScope.() -> Unit)? = PhotoBehind(job.mainsPhoto)

@Composable
private fun ActionSmalls(t: TileSet) {
    GlyphTile("log session", R.drawable.fluent_timer, s(), showLabel = false) { t.logSession() }
    GlyphTile("restrung", R.drawable.fluent_arrow_sync, s(), showLabel = false) { t.restrung() }
    CameraSmall(t.v)
}

/** PHO-01: the camera tile: a new restring for this racquet, starting with the package photo. */
@Composable
private fun CameraSmall(v: RacquetView) {
    val nav = LocalNav.current
    GlyphTile("camera", R.drawable.fluent_camera, s(), showLabel = false) { nav.open(Screen.RestringEdit(v.racquet.id, camera = true)) }
}

/** Layout 1, "grid": two rows of medium number tiles, the wide setup tile, small actions. */
@Composable
private fun LayoutGrid(v: RacquetView, pager: CategoryPagerState) {
    val t = tiles(v, pager)
    Column(verticalArrangement = Arrangement.spacedBy(gap())) {
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) { HoursTile(t, m(), m()); TensionTile(t) }
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) { DaysTile(t); FeelTile(t) }
        SetupTile(t)
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) { ActionSmalls(t) }
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
                Row(horizontalArrangement = Arrangement.spacedBy(gap())) {
                    GlyphTile("log session", R.drawable.fluent_timer, s(), showLabel = false) { t.logSession() }
                    GlyphTile("restrung", R.drawable.fluent_arrow_sync, s(), showLabel = false) { t.restrung() }
                }
            }
        }
        CameraSmall(v)
    }
}

/** Layout 3, "mixed": setup with tension on top, hours beside a block of four small tiles, feel wide. */
@Composable
private fun LayoutMixed(v: RacquetView, pager: CategoryPagerState) {
    val t = tiles(v, pager)
    Column(verticalArrangement = Arrangement.spacedBy(gap())) {
        SetupTile(t, withTension = true)
        Row(horizontalArrangement = Arrangement.spacedBy(gap())) {
            HoursTile(t, m(), m())
            Column(verticalArrangement = Arrangement.spacedBy(gap())) {
                Row(horizontalArrangement = Arrangement.spacedBy(gap())) {
                    GlyphTile("log session", R.drawable.fluent_timer, s(), showLabel = false) { t.logSession() }
                    GlyphTile("restrung", R.drawable.fluent_arrow_sync, s(), showLabel = false) { t.restrung() }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(gap())) { DaysTile(t, small = true); CameraSmall(v) }
            }
        }
        if (v.feels.isNotEmpty()) FeelTile(t, wide = true)
    }
}

/** NAV-02: this racquet's restrings, newest first, as Zune text rows. */
@Composable
private fun RestringList(r: Racquet, d: AppData) {
    val jobs = Strings.jobsFor(r.id, d.jobs)
    if (jobs.isEmpty()) return
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    SectionHeader("restrings")
    jobs.take(TennisTokens.Lists.recentRestrings).forEach { j ->
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
