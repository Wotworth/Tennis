package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** DET-02: what the app does with Health Connect data, shown from Health Connect's permission screen. */
@Composable
fun PrivacyScreen() {
    Page("privacy") {
        val gap = LocalZpx.current(10f)
        for (line in listOf(
            "This app reads heart rate, steps, workouts and resting heart rate from Health Connect.",
            "It uses them to find times you may have played tennis, and asks you before logging anything.",
            "The data stays on this phone. The app never sends it anywhere and never writes to Health Connect.",
            "You can take access away at any time in Health Connect's settings.",
        )) {
            TennisText(line, TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(gap))
        }
    }
}
