package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** NAV-08: settings. PH-0 has the diagnostics only; the rest arrives with the features. */
@Composable
fun SettingsScreen(version: String, onOpen: (Screen) -> Unit) {
    Page("settings") {
        TextRow("health connect report", "What your Fitbit data in Health Connect looks like, for one day", onClick = { onOpen(Screen.HealthReport) })
        TextRow("crash log", "Errors the app recorded, to paste into a session", onClick = { onOpen(Screen.CrashLog) })
        Spacer(Modifier.height(LocalZpx.current(12f)))
        TennisText("version $version", TennisTokens.Type.listSecondary)
    }
}
