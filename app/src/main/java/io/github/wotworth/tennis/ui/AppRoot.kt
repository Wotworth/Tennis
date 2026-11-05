package io.github.wotworth.tennis.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.ui.screens.CrashLogScreen
import io.github.wotworth.tennis.ui.screens.HealthReportScreen
import io.github.wotworth.tennis.ui.screens.Hub
import io.github.wotworth.tennis.ui.screens.SettingsScreen
import io.github.wotworth.tennis.ui.theme.TennisTheme

enum class Screen { Hub, Settings, HealthReport, CrashLog }

/** A plain back stack; back always ends at the hub (NAV-06). */
class Navigator(start: Screen = Screen.Hub) {
    val stack = mutableStateListOf(start)
    val current get() = stack.last()
    fun open(s: Screen) { stack.add(s) }
    fun back(): Boolean = if (stack.size > 1) { stack.removeAt(stack.lastIndex); true } else false
}

@Composable
fun AppRoot(app: TennisApp, nav: Navigator = remember { Navigator() }) {
    TennisTheme {
        BackHandler(enabled = nav.stack.size > 1) { nav.back() }
        when (nav.current) {
            Screen.Hub -> Hub(onSettings = { nav.open(Screen.Settings) })
            Screen.Settings -> SettingsScreen(app.versionText, onOpen = nav::open)
            Screen.HealthReport -> HealthReportScreen(app)
            Screen.CrashLog -> CrashLogScreen(app.crashLog)
        }
    }
}
