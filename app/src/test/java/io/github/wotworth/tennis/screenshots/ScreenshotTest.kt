package io.github.wotworth.tennis.screenshots

import androidx.compose.runtime.Composable
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.captureRoboImage
import io.github.wotworth.tennis.health.FakeDays
import io.github.wotworth.tennis.health.HealthSource
import io.github.wotworth.tennis.ui.screens.HealthReportContent
import io.github.wotworth.tennis.ui.screens.HealthReportState
import io.github.wotworth.tennis.ui.screens.Hub
import io.github.wotworth.tennis.ui.screens.PrivacyScreen
import io.github.wotworth.tennis.ui.screens.SettingsScreen
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

    private fun shoot(name: String, content: @Composable () -> Unit) {
        for ((label, qualifiers) in listOf("360dp" to W360, "411dp" to W411)) {
            RuntimeEnvironment.setQualifiers(qualifiers)
            captureRoboImage("build/outputs/roborazzi/$name-$label.png") { TennisTheme { content() } }
        }
    }

    private val tennisDay = HealthReportState(grantedCount = 5, day = FakeDays.day, data = FakeDays.playedTennis())

    @Test fun hubStrings() = shoot("hub-strings") { Hub(0) {} }
    @Test fun hubSessions() = shoot("hub-sessions") { Hub(1) {} }
    @Test fun hubCues() = shoot("hub-cues") { Hub(4) {} }
    @Test fun settings() = shoot("settings") { SettingsScreen("0.0.1 (1), built local build") {} }
    @Test fun healthReport() = shoot("health-report") { HealthReportContent(tennisDay, {}, {}, {}) }
    @Test fun healthNoAccess() = shoot("health-no-access") { HealthReportContent(HealthReportState(day = FakeDays.day), {}, {}, {}) }
    @Test fun healthMissing() = shoot("health-missing") {
        HealthReportContent(HealthReportState(availability = HealthSource.Availability.Missing), {}, {}, {})
    }
    @Test fun privacy() = shoot("privacy") { PrivacyScreen() }

    companion object {
        const val W360 = "w360dp-h780dp-port-xxhdpi"
        const val W411 = "w411dp-h891dp-port-420dpi"
    }
}
