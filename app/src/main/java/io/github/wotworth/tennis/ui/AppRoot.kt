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
    data class RestringEdit(val racquetId: Long, val jobId: Long? = null, val camera: Boolean = false) : Screen
    data class SessionEdit(val id: Long? = null, val proposalId: Long? = null, val racquetId: Long? = null) : Screen
    /** v0.4: one racquet's own pivot. */
    data class Racquet(val id: Long, val pivot: Int = 0) : Screen
    data class ShopOrder(val jobId: Long) : Screen
    data class CueEdit(val id: Long? = null) : Screen
    data class StringEdit(val id: Long? = null) : Screen
    /** DET-30: the Yes/No prompt. */
    data class Proposal(val id: Long) : Screen
    /** Tennis Vision (TV-APP-02, 04). */
    data class Vision(val id: String, val pivot: Int = 0) : Screen
    data class FootageTest(val id: String, val pivot: Int = 0) : Screen
    data class VisionShot(val id: String, val rally: Int, val index: Int) : Screen
    /** Chris, 17 Nov: one rally's 3D replay, its shots and heart rate. */
    data class VisionRally(val id: String, val rally: Int) : Screen
    data class VisionIdentity(val id: String) : Screen
    data object VisionTrends : Screen
    data object BallCheck : Screen
    /** TV-CAL-21: tap the four corners of the court for a camera whose line fit is doubtful. */
    data object CourtCorners : Screen
    data class OpponentPrompt(val sessionId: String) : Screen
    data object Opponents : Screen
    data class Opponent(val id: Int) : Screen
    data class MissedShot(val sessionId: String, val rally: Int) : Screen
    data class Court(val id: Long) : Screen
    data class CourtEdit(val id: Long? = null) : Screen
    /** Chris, 22 Nov, item 9: Tuesday's tape-measure numbers, as the PC's ground-truth file. */
    data object FieldNotes : Screen
    /** Chris, 22 Nov, item 14: the accuracy report's numbers. */
    data object Accuracy : Screen
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
                    is Screen.RestringEdit -> RestringEditScreen(s.racquetId, s.jobId, s.camera)
                    is Screen.SessionEdit -> SessionEditScreen(s.id, s.proposalId, s.racquetId)
                    is Screen.Racquet -> io.github.wotworth.tennis.ui.screens.RacquetHubScreen(s.id, s.pivot)
                    is Screen.ShopOrder -> ShopOrderScreen(s.jobId)
                    is Screen.CueEdit -> CueEditScreen(s.id)
                    is Screen.StringEdit -> StringEditScreen(s.id)
                    is Screen.Proposal -> io.github.wotworth.tennis.ui.screens.ProposalScreen(s.id)
                    is Screen.Vision -> io.github.wotworth.tennis.ui.screens.VisionSessionScreen(s.id, s.pivot)
                    is Screen.FootageTest -> io.github.wotworth.tennis.ui.screens.FootageTestScreen(s.id, s.pivot)
                    is Screen.VisionShot -> io.github.wotworth.tennis.ui.screens.VisionShotScreen(s.id, s.rally, s.index)
                    is Screen.VisionRally -> io.github.wotworth.tennis.ui.screens.VisionRallyScreen(s.id, s.rally)
                    Screen.BallCheck -> io.github.wotworth.tennis.ui.screens.BallCheckScreen()
                    Screen.CourtCorners -> io.github.wotworth.tennis.ui.screens.CourtCornersScreen()
                    is Screen.OpponentPrompt -> io.github.wotworth.tennis.ui.screens.OpponentPromptScreen(s.sessionId)
                    Screen.Opponents -> io.github.wotworth.tennis.ui.screens.OpponentsScreen()
                    is Screen.Opponent -> io.github.wotworth.tennis.ui.screens.OpponentScreen(s.id)
                    is Screen.MissedShot -> io.github.wotworth.tennis.ui.screens.MissedShotScreen(s.sessionId, s.rally)
                    Screen.VisionTrends -> io.github.wotworth.tennis.ui.screens.VisionTrendsScreen()
                    is Screen.VisionIdentity -> io.github.wotworth.tennis.ui.screens.VisionIdentityScreen(s.id)
                    is Screen.Court -> io.github.wotworth.tennis.ui.screens.CourtScreen(s.id)
                    is Screen.CourtEdit -> io.github.wotworth.tennis.ui.screens.CourtEditScreen(s.id)
                    Screen.FieldNotes -> io.github.wotworth.tennis.ui.screens.FieldNotesScreen()
                    Screen.Accuracy -> io.github.wotworth.tennis.ui.screens.AccuracyScreen()
                }
                OverlayHost(overlays)
            }
        }
    }
}

/** The data, as Compose state. */
@Composable
fun appData() = LocalApp.current.repo.data.collectAsState().value
