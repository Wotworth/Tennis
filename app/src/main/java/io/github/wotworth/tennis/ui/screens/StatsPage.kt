package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** NAV-04: stats. Filled in PH-5 (section 9). */
@Composable
fun StatsPage() {
    PivotColumn {
        StatsContent.content?.invoke() ?: run {
            TennisText("Hours, feel and spending.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(LocalZpx.current(6f)))
            TennisText("Arrives in PH-5.", TennisTokens.Type.listSecondary)
        }
    }
}

object StatsContent { var content: (@Composable () -> Unit)? = null }
