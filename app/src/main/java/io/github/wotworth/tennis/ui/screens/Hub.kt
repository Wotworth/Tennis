package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.AppBar
import io.github.wotworth.tennis.ui.components.AppTitle
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.motion.CategoryPagerState
import io.github.wotworth.tennis.ui.motion.PagerCategoryBar
import io.github.wotworth.tennis.ui.motion.PagerContent
import io.github.wotworth.tennis.ui.motion.rememberCategoryPager
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisTokens

/**
 * NAV-01 (v0.4): the five pivots. Cues first, since the app opens on it; "racquets" (was
 * "strings") lists every racquet, People-hub style.
 */
val PIVOTS = listOf("cues", "racquets", "sessions", "stats", "library")
const val CUES = 0
const val RACQUETS = 1
const val SESSIONS = 2
const val STATS = 3
const val LIBRARY = 4

/**
 * A Windows Phone pivot: the small all-caps [title], the pages' lowercase headers with the next
 * one peeking in, the pages, and an application bar that changes with the page.
 */
@Composable
fun PivotScreen(
    title: String,
    pivots: List<String>,
    initial: Int,
    onChange: (Int) -> Unit,
    bar: @Composable (CategoryPagerState) -> List<BarButton>,
    onMore: () -> Unit,
    content: @Composable (Int, CategoryPagerState) -> Unit,
) {
    val zpx = LocalZpx.current
    val pager = rememberCategoryPager(pivots.size, initial, onChange)
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        AppTitle(text = title)
        PagerCategoryBar(pager, pivots)
        Box(Modifier.fillMaxSize().padding(top = zpx(TennisTokens.Layout.pivotContentTop))) {
            PagerContent(pager) { i -> content(i, pager) }
        }
        AppBar(bar(pager), Modifier.align(Alignment.BottomCenter), onMore = onMore)
    }
}

/** NAV-01: the main hub. */
@Composable
fun Hub(initial: Int = CUES) {
    val nav = LocalNav.current
    PivotScreen(
        "tennis", PIVOTS, initial,
        onChange = { nav.stack[0] = Screen.Hub(it) },
        bar = { p -> barFor(p.selected) },
        onMore = { nav.open(Screen.Settings) },
    ) { i, pager ->
        // CUE-10: the screen stays on while the cues (warmup) page shows.
        if (i == CUES) KeepScreenOn(pager.selected == CUES)
        when (i) {
            CUES -> CuesPage()
            RACQUETS -> RacquetsPage()
            SESSIONS -> SessionsPage()
            STATS -> StatsPage()
            LIBRARY -> LibraryPage()
        }
    }
}

@Composable
fun KeepScreenOn(on: Boolean) {
    val view = LocalView.current
    DisposableEffect(on) {
        view.keepScreenOn = on
        onDispose { view.keepScreenOn = false }
    }
}

@Composable
private fun barFor(pivot: Int): List<BarButton> {
    val nav = LocalNav.current
    return when (pivot) {
        CUES -> listOf(BarButton(R.drawable.fluent_add, "add cue") { nav.open(Screen.CueEdit()) })
        RACQUETS -> listOf(BarButton(R.drawable.fluent_add, "add racquet") { nav.open(Screen.RacquetEdit()) })
        SESSIONS -> listOf(BarButton(R.drawable.fluent_add, "log session") { nav.open(Screen.SessionEdit()) })
        LIBRARY -> listOf(BarButton(R.drawable.fluent_add, "add string") { nav.open(Screen.StringEdit()) })
        else -> emptyList()
    }
}

/** A pivot page's scrolling column, at the page margins, clear of the app bar. */
@Composable
fun PivotColumn(content: @Composable ColumnScope.() -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = zpx(l.pageSideMargin)),
    ) {
        content()
        Spacer(Modifier.height(zpx(l.appBarHeight + 16f)))
        Spacer(Modifier.navigationBarsPadding())
    }
}
