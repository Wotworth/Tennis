package io.github.wotworth.tennis.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.theme.GiantHeader
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** A page below the hub: the giant gradient title, then a scrolling column at the page margins. */
@Composable
fun Page(title: String, content: @Composable ColumnScope.() -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        GiantHeader(title)
        Column(
            Modifier
                .fillMaxSize()
                .padding(top = zpx(l.giantHeaderBaseline + 30f))
                .verticalScroll(rememberScrollState())
                .padding(horizontal = zpx(l.pageSideMargin))
                .navigationBarsPadding(),
        ) {
            content()
            Spacer(Modifier.height(zpx(l.listBottomPadding)))
        }
    }
}

/** A Zune-style text row: primary line, optional grey secondary line, tilt on press. */
@Composable
fun TextRow(primary: String, secondary: String? = null, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    val zpx = LocalZpx.current
    Column(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.press(description = primary, onClick = onClick) else Modifier)
            .padding(bottom = zpx(TennisTokens.Layout.listRowGap)),
    ) {
        TennisText(primary, TennisTokens.Type.listPrimary)
        if (secondary != null) {
            Spacer(Modifier.height(zpx(4f)))
            TennisText(secondary, TennisTokens.Type.listSecondary)
        }
    }
}
