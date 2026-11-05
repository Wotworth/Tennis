package io.github.wotworth.tennis.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.applyCase
import io.github.wotworth.tennis.ui.theme.textStyleFor
import io.github.wotworth.tennis.ui.theme.titleGradient

/** The small all-caps title at the top of every page: the app's, or a racquet's name in its own pivot (v0.4). */
@Composable
fun AppTitle(modifier: Modifier = Modifier, text: String = "tennis") {
    val zpx = LocalZpx.current
    TennisText(text, TennisTokens.Type.appTitle, modifier.padding(start = zpx(TennisTokens.Layout.pageSideMargin)).baselineAt(zpx(TennisTokens.Layout.appTitleBaseline)), maxLines = 1)
}

/** A page's large lowercase header in the title gradient, cut with "…" if too long (never clipped mid-letter). */
@Composable
fun PageHeader(text: String) {
    val zpx = LocalZpx.current
    val role = TennisTokens.Type.pageHeader
    BasicText(
        applyCase(text, role.case),
        style = textStyleFor(role),
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .padding(start = zpx(TennisTokens.Layout.pivotHeaderLeft))
            .baselineAt(zpx(TennisTokens.Layout.pivotHeaderBaseline - TennisTokens.Layout.appTitleBaseline))
            .titleGradient(),
    )
}

/**
 * A page below the hub (NAV-07): app title, page header, a scrolling column at the page margins,
 * and an optional application bar.
 */
@Composable
fun Page(title: String, bar: List<BarButton> = emptyList(), content: @Composable ColumnScope.() -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.fillMaxSize()) {
            AppTitle()
            PageHeader(title)
            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = zpx(l.pageSideMargin))
                    .padding(top = zpx(14f)),
            ) {
                content()
                Spacer(Modifier.height(zpx(if (bar.isEmpty()) 24f else l.appBarHeight + 16f)))
                Spacer(Modifier.navigationBarsPadding())
            }
        }
        if (bar.isNotEmpty()) AppBar(bar, Modifier.align(Alignment.BottomCenter))
    }
}

/** A Zune-style text row: primary line, optional grey secondary line, tilt on press. */
@Composable
fun TextRow(primary: String, secondary: String? = null, modifier: Modifier = Modifier, onLongClick: (() -> Unit)? = null, onClick: (() -> Unit)? = null) {
    val zpx = LocalZpx.current
    Column(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null || onLongClick != null) Modifier.press(onLongClick = onLongClick, description = primary, onClick = onClick ?: {}) else Modifier)
            .padding(bottom = zpx(TennisTokens.Layout.listRowGap)),
    ) {
        TennisText(primary, TennisTokens.Type.listPrimary)
        if (secondary != null) {
            Spacer(Modifier.height(zpx(4f)))
            TennisText(secondary, TennisTokens.Type.listSecondary)
        }
    }
}
