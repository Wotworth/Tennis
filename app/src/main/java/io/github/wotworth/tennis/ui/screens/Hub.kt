package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.ui.components.GlyphTile
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.motion.LocalSlideIn
import io.github.wotworth.tennis.ui.motion.PagerCategoryBar
import io.github.wotworth.tennis.ui.motion.PagerContent
import io.github.wotworth.tennis.ui.motion.rememberCategoryPager
import io.github.wotworth.tennis.ui.motion.slideIn
import io.github.wotworth.tennis.ui.theme.GiantHeader
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** NAV-01: the five pivots, swiped horizontally (cues as the fifth, from Chris on 5 Nov). */
val PIVOTS = listOf("strings", "sessions", "stats", "library", "cues")

/**
 * NAV-01: the hub. PH-0 has the structure only; each pivot says what arrives in which phase. The
 * strings pivot shows its tiles as a static preview of the look (VIS-04), so the green can be
 * judged on the phone before PH-1 builds them.
 */
@Composable
fun Hub(initial: Int = 0, onSettings: () -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    val pager = rememberCategoryPager(PIVOTS.size, initial) {}
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        GiantHeader("tennis")
        PagerCategoryBar(pager, PIVOTS)
        Box(Modifier.fillMaxSize().padding(top = zpx(l.listTop - 6f))) {
            PagerContent(pager) { i ->
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(androidx.compose.foundation.rememberScrollState())
                        .padding(horizontal = zpx(l.pageSideMargin))
                        .navigationBarsPadding()
                        .padding(bottom = zpx(l.appBarHeight + 8f)),
                ) {
                    when (PIVOTS[i]) {
                        "strings" -> StringsPreview()
                        "sessions" -> Coming("Your sessions, newest first.", "Logging by hand arrives in PH-1; sessions found from your Fitbit in PH-2.")
                        "stats" -> Coming("Hours, feel and spending.", "Arrives in PH-5.")
                        "library" -> Coming("Past string jobs and your strings.", "Arrives in PH-1.")
                        "cues" -> Coming("Swing cues and the warmup view.", "Arrives in PH-5.")
                    }
                }
            }
        }
        AppBar(Modifier.align(Alignment.BottomEnd), onSettings)
    }
}

@Composable
private fun Coming(what: String, phase: String) {
    val zpx = LocalZpx.current
    val slide = LocalSlideIn.current
    val px = with(LocalDensity.current) { zpx(1f).toPx() }
    TennisText(what, TennisTokens.Type.listPrimary, Modifier.slideIn(slide, px) { 0 })
    Spacer(Modifier.height(zpx(6f)))
    TennisText(phase, TennisTokens.Type.listSecondary, Modifier.slideIn(slide, px) { 1 })
}

/** VIS-04, NAV-02: the strings pivot's tiles, not yet working (PH-1). */
@Composable
private fun StringsPreview() {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    val slide = LocalSlideIn.current
    val px = with(LocalDensity.current) { zpx(1f).toPx() }
    val full = TennisTokens.ZUNE_SCREEN_WIDTH_ZPX - 2 * l.pageSideMargin
    val half = (full - l.tileGap) / 2
    val gap = zpx(l.tileGap)
    Column(verticalArrangement = Arrangement.spacedBy(gap)) {
        Tile("hours on these strings", zpx(full), zpx(116f), Modifier.slideIn(slide, px) { 0 }) {
            TennisText("0", TennisTokens.Type.headlineNumber, Modifier.align(Alignment.TopStart))
        }
        Tile("current setup", zpx(full), zpx(68f), Modifier.slideIn(slide, px) { 1 }) {
            TennisText("No string job yet", TennisTokens.Type.listPrimary, Modifier.align(Alignment.TopStart), maxLines = 1)
        }
        Row(Modifier.slideIn(slide, px) { 2 }, horizontalArrangement = Arrangement.spacedBy(gap)) {
            GlyphTile("log session", R.drawable.fluent_timer, zpx(half))
            GlyphTile("restrung", R.drawable.fluent_arrow_sync, zpx(half))
        }
        Row(Modifier.slideIn(slide, px) { 3 }, horizontalArrangement = Arrangement.spacedBy(gap)) {
            GlyphTile("camera", R.drawable.fluent_camera, zpx(half))
            GlyphTile("warmup", R.drawable.fluent_note, zpx(half))
        }
        Spacer(Modifier.height(zpx(4f)))
        TennisText("These tiles are a preview of the look. They start working in PH-1.", TennisTokens.Type.listSecondary)
    }
}

/** NAV-08: the Windows Phone app bar's "…", bottom right, opening settings. */
@Composable
private fun AppBar(modifier: Modifier, onSettings: () -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(
        modifier
            .navigationBarsPadding()
            .padding(end = zpx(l.pageSideMargin - 6f), bottom = zpx(4f))
            .size(zpx(l.appBarHeight))
            .press(description = "settings", onClick = onSettings),
        contentAlignment = Alignment.Center,
    ) {
        Image(painterResource(R.drawable.fluent_more_horizontal), contentDescription = null, modifier = Modifier.size(zpx(l.appBarDotsSize * 0.6f)))
    }
}
