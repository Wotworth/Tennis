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
 * NAV-01 (v0.3): the five pivots. Cues first, since the app opens on it (Chris, 5 Nov); the
 * others follow to its right.
 */
val PIVOTS = listOf("cues", "strings", "sessions", "stats", "library")
const val CUES = 0
const val STRINGS = 1
const val SESSIONS = 2
const val STATS = 3
const val LIBRARY = 4

/**
 * NAV-01: the hub as a Windows Phone pivot (v0.3 title, option a): "TENNIS" small at the top,
 * the pages' lowercase headers below it with the next one peeking in from the right, and an
 * application bar that changes with the page.
 */
@Composable
fun Hub(initial: Int = CUES) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    val nav = LocalNav.current
    val pager = rememberCategoryPager(PIVOTS.size, initial) { nav.stack[0] = Screen.Hub(it) }
    // CUE-10: the screen stays on while the cues (warmup) page shows.
    val view = LocalView.current
    DisposableEffect(pager.selected) {
        view.keepScreenOn = pager.selected == CUES
        onDispose { view.keepScreenOn = false }
    }
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        AppTitle()
        PagerCategoryBar(pager, PIVOTS)
        Box(Modifier.fillMaxSize().padding(top = zpx(l.pivotContentTop))) {
            PagerContent(pager) { i ->
                when (i) {
                    CUES -> CuesPage()
                    STRINGS -> StringsPage(pager)
                    SESSIONS -> SessionsPage()
                    STATS -> StatsPage()
                    LIBRARY -> LibraryPage()
                }
            }
        }
        AppBar(barFor(pager.selected), Modifier.align(Alignment.BottomCenter), onMore = { nav.open(Screen.Settings) })
    }
}

@Composable
private fun barFor(pivot: Int): List<BarButton> {
    val nav = LocalNav.current
    return when (pivot) {
        CUES -> listOf(BarButton(R.drawable.fluent_add, "add cue") { nav.open(Screen.CueEdit()) })
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

/** For the strings page's tiles that open another pivot. */
fun CategoryPagerState.go(i: Int) = select(i)
