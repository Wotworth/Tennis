package io.github.wotworth.tennis.screenshots

import androidx.compose.runtime.Composable
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.health.FakeDays
import io.github.wotworth.tennis.health.HealthSource
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.screens.CUES
import io.github.wotworth.tennis.ui.screens.HealthReportContent
import io.github.wotworth.tennis.ui.screens.HealthReportState
import io.github.wotworth.tennis.ui.screens.LIBRARY
import io.github.wotworth.tennis.ui.screens.SESSIONS
import io.github.wotworth.tennis.ui.screens.STRINGS
import io.github.wotworth.tennis.ui.theme.TennisTheme
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * PLT-05: one render per screen state at the S25's portrait sizes: 360 dp wide at 3.0x (default
 * screen zoom) and 411 dp wide at 2.625x. Images land in app/build/outputs/roborazzi/.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = ScreenshotTest.W360)
class ScreenshotTest {

    init {
        io.github.wotworth.tennis.ui.motion.stillForScreenshots = true
    }

    private fun shoot(name: String, both: Boolean = true, content: @Composable () -> Unit) {
        for ((label, qualifiers) in listOf("360dp" to W360, "411dp" to W411).take(if (both) 2 else 1)) {
            RuntimeEnvironment.setQualifiers(qualifiers)
            captureRoboImage("build/outputs/roborazzi/$name-$label.png") { content() }
        }
    }

    private fun screen(name: String, s: Screen, app: TennisApp = Sample.fill(), both: Boolean = true) =
        shoot(name, both) { AppRoot(app, Navigator(s)) }

    @Test fun cues() = screen("hub-cues", Screen.Hub(CUES))
    @Test fun cuesWithProposal() = screen("hub-cues-proposal", Screen.Hub(CUES), Sample.fill(proposals = true), both = false)
    @Test fun cuesEmpty() = screen("hub-cues-empty", Screen.Hub(CUES), Sample.empty(), both = false)
    @Test fun stringsGrid() = screen("hub-strings-1-grid", Screen.Hub(STRINGS), Sample.fill(layout = 1))
    @Test fun stringsHero() = screen("hub-strings-2-hero", Screen.Hub(STRINGS), Sample.fill(layout = 2))
    @Test fun stringsMixed() = screen("hub-strings-3-mixed", Screen.Hub(STRINGS), Sample.fill(layout = 3))
    @Test fun stringsEmpty() = screen("hub-strings-empty", Screen.Hub(STRINGS), Sample.empty(), both = false)
    @Test fun sessions() = screen("hub-sessions", Screen.Hub(SESSIONS))
    @Test fun library() = screen("hub-library", Screen.Hub(LIBRARY), both = false)
    @Test fun restrungForm() {
        val app = Sample.fill()
        screen("restrung", Screen.RestringEdit(app.repo.data.value.racquets.first().id), app)
    }
    @Test fun sessionForm() = screen("session-new", Screen.SessionEdit())
    @Test fun proposal() {
        val app = Sample.fill(proposals = true)
        screen("proposal", Screen.Proposal(app.repo.data.value.proposals.first().id), app, both = false)
    }
    @Test fun shopOrder() {
        val app = Sample.fill()
        screen("shop-order", Screen.ShopOrder(app.repo.data.value.jobs.first().id), app)
    }
    @Test fun racquetForm() = screen("racquet-new", Screen.RacquetEdit(), both = false)
    @Test fun cueForm() = screen("cue-new", Screen.CueEdit(), both = false)
    @Test fun settings() = screen("settings", Screen.Settings, both = false)
    @Test fun debug() = screen("debug", Screen.Debug, both = false)

    private val tennisDay = HealthReportState(grantedCount = 5, day = FakeDays.day, data = FakeDays.playedTennis())
    @Test fun healthReport() = shoot("health-report", both = false) { TennisTheme { HealthReportContent(tennisDay, {}, {}, {}) } }
    @Test fun healthNoAccess() = shoot("health-no-access", both = false) { TennisTheme { HealthReportContent(HealthReportState(day = FakeDays.day), {}, {}, {}) } }
    @Test fun healthMissing() = shoot("health-missing", both = false) {
        TennisTheme { HealthReportContent(HealthReportState(availability = HealthSource.Availability.Missing), {}, {}, {}) }
    }

    companion object {
        const val W360 = "w360dp-h780dp-port-xxhdpi"
        const val W411 = "w411dp-h891dp-port-420dpi"
    }
}
