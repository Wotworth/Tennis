package io.github.wotworth.tennis.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.OverlayHost
import io.github.wotworth.tennis.ui.components.Overlays
import io.github.wotworth.tennis.ui.screens.CrashLogScreen
import io.github.wotworth.tennis.ui.screens.CueEditScreen
import io.github.wotworth.tennis.ui.screens.HealthReportScreen
import io.github.wotworth.tennis.ui.screens.Hub
import io.github.wotworth.tennis.ui.screens.RacquetEditScreen
import io.github.wotworth.tennis.ui.screens.RestringEditScreen
import io.github.wotworth.tennis.ui.screens.SessionEditScreen
import io.github.wotworth.tennis.ui.screens.SettingsScreen
import io.github.wotworth.tennis.ui.screens.ShopOrderScreen
import io.github.wotworth.tennis.ui.screens.StringEditScreen
import io.github.wotworth.tennis.ui.theme.TennisTheme

sealed interface Screen {
    data class Hub(val pivot: Int = 0) : Screen
    data object Settings : Screen
    data object HealthReport : Screen
    data object CrashLog : Screen
    data object Debug : Screen
    data class RacquetEdit(val id: Long? = null) : Screen
    data class RestringEdit(val racquetId: Long, val jobId: Long? = null) : Screen
    data class SessionEdit(val id: Long? = null, val proposalId: Long? = null) : Screen
    data class ShopOrder(val jobId: Long) : Screen
    data class CueEdit(val id: Long? = null) : Screen
    data class StringEdit(val id: Long? = null) : Screen
    /** DET-30: the Yes/No prompt. */
    data class Proposal(val id: Long) : Screen
}

/** A plain back stack; back always ends at the hub (NAV-06). */
class Navigator(start: Screen = Screen.Hub()) {
    val stack = mutableStateListOf(start)
    val current get() = stack.last()
    fun open(s: Screen) { stack.add(s) }
    fun back(): Boolean = if (stack.size > 1) { stack.removeAt(stack.lastIndex); true } else false
    /** TIL-11: start over at [s] (opened from the launcher tile). */
    fun reset(s: Screen) { stack.clear(); stack.add(Screen.Hub()); if (s !is Screen.Hub) stack.add(s) }
}

val LocalApp = staticCompositionLocalOf<TennisApp> { error("no app") }
val LocalNav = staticCompositionLocalOf { Navigator() }

@Composable
fun AppRoot(app: TennisApp, nav: Navigator = remember { Navigator() }, overlays: Overlays = remember { Overlays() }) {
    TennisTheme {
        CompositionLocalProvider(LocalApp provides app, LocalNav provides nav, LocalOverlays provides overlays) {
            BackHandler(enabled = overlays.current != null) { overlays.dismiss() }
            BackHandler(enabled = overlays.current == null && nav.stack.size > 1) { nav.back() }
            Box {
                when (val s = nav.current) {
                    is Screen.Hub -> Hub(s.pivot)
                    Screen.Settings -> SettingsScreen()
                    Screen.HealthReport -> HealthReportScreen(app)
                    Screen.CrashLog -> CrashLogScreen(app.crashLog)
                    Screen.Debug -> io.github.wotworth.tennis.ui.screens.DebugScreen()
                    is Screen.RacquetEdit -> RacquetEditScreen(s.id)
                    is Screen.RestringEdit -> RestringEditScreen(s.racquetId, s.jobId)
                    is Screen.SessionEdit -> SessionEditScreen(s.id, s.proposalId)
                    is Screen.ShopOrder -> ShopOrderScreen(s.jobId)
                    is Screen.CueEdit -> CueEditScreen(s.id)
                    is Screen.StringEdit -> StringEditScreen(s.id)
                    is Screen.Proposal -> io.github.wotworth.tennis.ui.screens.ProposalScreen(s.id)
                }
                OverlayHost(overlays)
            }
        }
    }
}

/** The data, as Compose state. */
@Composable
fun appData() = LocalApp.current.repo.data.collectAsState().value
