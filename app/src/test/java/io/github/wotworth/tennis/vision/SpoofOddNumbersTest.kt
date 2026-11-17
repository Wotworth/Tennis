package io.github.wotworth.tennis.vision

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.github.wotworth.tennis.Sample
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.ui.AppRoot
import io.github.wotworth.tennis.ui.Navigator
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.screens.SESSIONS
import io.github.wotworth.tennis.ui.screens.VisionDefaults
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Chris, 16 Nov: the bundled spoof session has no even numbers anywhere, so any even number on a
 * vision screen did not come from the session (a bug, a constant or a label). This renders every
 * vision screen on the spoof session, on a tall window so whole lists are composed, collects every
 * text on it (and the few numbers drawn straight onto charts, [CanvasText]) and fails on any run
 * number (with its decimals) whose last digit is even (so 8.9 passes, 8.2 and 1.0 do not), except the app's own fixed labels listed in [allowed].
 * The report is written to build/outputs/spoof-numbers.txt.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w411dp-h9000dp-port-420dpi")
class SpoofOddNumbersTest {
    @get:Rule val rule = createComposeRule()

    /** The app's own wording, not session numbers (each explained in docs/reports/SPOOF-SESSION.md). */
    private val allowed = listOf(
        Regex("""\d+ rpm ± \d+"""),                     // rpm is shown to the nearest 10 rpm, so it always ends in 0
        Regex("""^(30|90) mph$|^12 ft shorter$"""),        // the court map's colour scale (TennisTokens.Vision)
        Regex("""^180 · 140 · 100 bpm$"""),                // the heart-rate chart's grid lines
        Regex("""^\d+–\d+%$|^90%\+$"""),                   // the heart-rate zone names
        // the bundled footage tests' rows on the sessions page: real iPhone footage, not the spoof
        // session (Chris, 17 Nov)
        Regex("""^iPhone test \d+$|^footage test · \d+ \w+ \d+$|^\d+ rallies · ball found in \d+% of frames$"""),
    )

    private var current = androidx.compose.runtime.mutableStateOf<Pair<Int, Screen>?>(null)
    private var n = 0

    private fun texts(app: TennisApp, s: Screen): List<String> {
        CanvasText.record = true; CanvasText.seen.clear()
        if (current.value == null) rule.setContent {
            current.value?.let { (k, scr) -> androidx.compose.runtime.key(k) { AppRoot(app, Navigator(scr)) } }
        }
        current.value = (++n) to s          // a new key: the screen is composed afresh
        rule.waitForIdle()
        val nodes = rule.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Text), useUnmergedTree = true).fetchSemanticsNodes()
        val t = nodes.flatMap { n -> n.config[SemanticsProperties.Text].map { it.text } } +
            nodes.mapNotNull { n -> if (n.config.contains(SemanticsProperties.ContentDescription)) n.config[SemanticsProperties.ContentDescription].joinToString(" ") else null }
        CanvasText.record = false
        return t + CanvasText.seen.map { "[chart] $it" }
    }

    private fun evens(text: String, screen: String = ""): List<String> {
        // time in each heart-rate zone: worked out on the phone from the birth year set there (the
        // max heart rate), so not something the session file can fix; the chart's own length is
        // checked by the spoof generator instead
        if (screen.endsWith("pivot 5") && Regex("""^\d+ min$""").matches(text)) return emptyList()
        var t = text
        allowed.forEach { t = it.replace(t, "") }
        return Regex("""\d+(?:\.\d+)?""").findAll(t).map { it.value }.filter { (it.last() - '0') % 2 == 0 }.toList()
    }

    @Test fun everyVisionScreenShowsOnlyOddNumbers() {
        val app = Sample.empty()
        app.prefs.chooseVisionSample(true)
        val v = app.vision.session(VisionStore.SAMPLE_ID)!!
        val screens = mutableListOf<Pair<String, Screen>>("sessions" to Screen.Hub(SESSIONS))
        fun all(tag: String) {
            (0..5).forEach { screens += "$tag pivot $it" to Screen.Vision(v.id, it) }
            v.shots.forEach { screens += "$tag shot ${it.rally}.${it.index}" to Screen.VisionShot(v.id, it.rally, it.index) }
            screens += "$tag trends" to Screen.VisionTrends
        }
        all("before")
        screens += "which one" to Screen.VisionIdentity(v.id)
        screens += "ball check" to Screen.BallCheck
        val bad = mutableListOf<String>()
        val report = StringBuilder()
        fun scan(list: List<Pair<String, Screen>>) = list.forEach { (name, s) ->
            for (type in listOf("all", "forehand", "backhand", "serve")) for (colour in listOf("speed", "spin")) {
                if (s !is Screen.Vision || s.pivot != 1) { if (type != "all" || colour != "speed") continue }
                VisionDefaults.courtType = type; VisionDefaults.courtColour = colour
                val label = if (s is Screen.Vision && s.pivot == 1) "$name $type/$colour" else name
                texts(app, s).forEach { t ->
                    val e = evens(t, name)
                    report.append("$label | $t").append(if (e.isEmpty()) "" else "   <-- EVEN ${e.joinToString()}").append('\n')
                    if (e.isNotEmpty()) bad += "$label: \"$t\""
                }
            }
        }
        scan(screens)
        // after "which one is you?" is answered: the per-player figures change
        app.prefs.answerVisionSampleIdentity("Player A")
        screens.clear(); all("after"); scan(screens)
        VisionDefaults.courtType = "all"; VisionDefaults.courtColour = "speed"
        java.io.File("build/outputs").mkdirs()
        java.io.File("build/outputs/spoof-numbers.txt").writeText(report.toString())
        assertTrue("even numbers on the spoof session:\n" + bad.distinct().joinToString("\n"), bad.isEmpty())
    }
}
