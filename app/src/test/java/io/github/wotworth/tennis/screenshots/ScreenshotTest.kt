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
import io.github.wotworth.tennis.ui.screens.RACQUETS
import io.github.wotworth.tennis.ui.theme.TennisTheme
import org.junit.Test
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.unit.dp
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
    private fun bb1(app: TennisApp) = app.repo.data.value.racquets.first { it.name == "Black Blade #1" }.id
    @Test fun racquets() = screen("hub-racquets", Screen.Hub(RACQUETS))
    @Test fun racquetsEmpty() = screen("hub-racquets-empty", Screen.Hub(RACQUETS), Sample.empty(), both = false)
    @Test fun racquetGrid() { val a = Sample.fill(layout = 1); screen("racquet-strings-1-grid", Screen.Racquet(bb1(a)), a) }
    @Test fun racquetHero() { val a = Sample.fill(layout = 2); screen("racquet-strings-2-hero", Screen.Racquet(bb1(a)), a, both = false) }
    @Test fun racquetMixed() { val a = Sample.fill(layout = 3); screen("racquet-strings-3-mixed", Screen.Racquet(bb1(a)), a, both = false) }
    @Test fun racquetHistory() { val a = Sample.fill(); screen("racquet-history", Screen.Racquet(bb1(a), 1), a, both = false) }
    @Test fun racquetSessions() { val a = Sample.fill(); screen("racquet-sessions", Screen.Racquet(bb1(a), 2), a, both = false) }
    @Test fun retiredRacquet() { val a = Sample.fill(); screen("racquet-retired", Screen.Racquet(a.repo.data.value.retired.first().id), a, both = false) }
    @Test fun racquetMenu() {
        val a = Sample.fill(); val o = io.github.wotworth.tennis.ui.components.Overlays()
        o.menu("edit racquet" to {}, "retire racquet" to {}, "delete racquet" to {}, "settings" to {})
        shoot("racquet-menu", false) { AppRoot(a, Navigator(Screen.Racquet(bb1(a))), o) }
    }
    @Test fun sessions() = screen("hub-sessions", Screen.Hub(SESSIONS))
    @Test fun stats() = screen("hub-stats", Screen.Hub(io.github.wotworth.tennis.ui.screens.STATS))
    @Test fun library() = screen("hub-library", Screen.Hub(LIBRARY), both = false)
    @Test fun restrungForm() {
        val app = Sample.fill()
        screen("restrung", Screen.RestringEdit(app.repo.data.value.racquets.first().id), app)
    }
    @Test fun stringsWithPhoto() {
        val app = Sample.fill(layout = 1)
        // A made-up "package photo": a gradient with text-like bars, saved where photos go.
        val f = io.github.wotworth.tennis.photos.Photos.file(app, "pkg-test.jpg")
        val b = android.graphics.Bitmap.createBitmap(800, 600, android.graphics.Bitmap.Config.ARGB_8888)
        android.graphics.Canvas(b).apply {
            drawColor(android.graphics.Color.rgb(230, 200, 40))
            val p = android.graphics.Paint().apply { color = android.graphics.Color.rgb(20, 20, 20) }
            drawRect(80f, 120f, 700f, 220f, p); drawRect(80f, 280f, 520f, 330f, p)
        }
        f.outputStream().use { b.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) }
        val d = app.repo.data.value
        val j = io.github.wotworth.tennis.domain.Strings.currentJob(app.prefs.selectedRacquet, d.jobs)!!
        kotlinx.coroutines.runBlocking { app.repo.saveJob(j.copy(mainsPhoto = "pkg-test.jpg")) }
        Sample.waitFor(app) { it.jobs.any { j2 -> j2.mainsPhoto != null } }
        io.github.wotworth.tennis.ui.screens.PhotoCache.load(app, "pkg-test.jpg", 720)
        screen("hub-racquets-photo", Screen.Hub(RACQUETS), app, both = false)
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

    /** TIL-04: the plain racket icon, on the tile green, as a medium tile and as the app icon. */
    @Test fun racketIcon() = shoot("racket-icon", both = false) {
        TennisTheme {
            androidx.compose.foundation.layout.Row(androidx.compose.ui.Modifier.padding(24.dp)) {
                io.github.wotworth.tennis.ui.components.GlyphTile("tennis", io.github.wotworth.tennis.R.drawable.glyph_racket, io.github.wotworth.tennis.ui.theme.LocalZpx.current(116f))
                androidx.compose.foundation.layout.Spacer(androidx.compose.ui.Modifier.width(io.github.wotworth.tennis.ui.theme.LocalZpx.current(8f)))
                androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.size(io.github.wotworth.tennis.ui.theme.LocalZpx.current(116f)).background(io.github.wotworth.tennis.ui.theme.TennisTokens.Colors.tile)) {
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(io.github.wotworth.tennis.R.drawable.ic_launcher_foreground), null, androidx.compose.ui.Modifier.fillMaxSize())
                }
            }
        }
    }

    companion object {
        const val W360 = "w360dp-h780dp-port-xxhdpi"
        const val W411 = "w411dp-h891dp-port-420dpi"
    }
}
