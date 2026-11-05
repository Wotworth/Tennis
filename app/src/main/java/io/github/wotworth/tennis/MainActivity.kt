package io.github.wotworth.tennis

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import kotlinx.coroutines.launch
import io.github.wotworth.tennis.ui.AppRoot

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // VIS-08: black, edge to edge, status bar visible with light icons.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        handle(intent)
        selfTest(intent)
        setContent { AppRoot(application as TennisApp, nav) }
    }

    private val nav = io.github.wotworth.tennis.ui.Navigator()

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
    }

    /**
     * CI only (BuildConfig.SELFTEST, the emulatorCheck build): reads the bundled sample package
     * with ML Kit exactly as a photo would be read, and logs the result for the workflow.
     */
    private fun selfTest(intent: android.content.Intent?) {
        if (!BuildConfig.SELFTEST || intent?.action != "io.github.wotworth.tennis.SELFTEST") return
        val app = application as TennisApp
        app.scope.launch {
            val line = try {
                val f = java.io.File(cacheDir, "selftest-package.png")
                assets.open("selftest-package.png").use { input -> f.outputStream().use { input.copyTo(it) } }
                val text = io.github.wotworth.tennis.photos.Photos.readText(this@MainActivity, f)
                val spec = io.github.wotworth.tennis.photos.PackageText.read(text)
                "OK brand=${spec.brand} model=${spec.model} gauge=${spec.gauge} material=${spec.material} text=${text.replace('\n', '|')}"
            } catch (e: Throwable) {
                "FAIL ${e.javaClass.name}: ${e.message}"
            }
            android.util.Log.i("TennisSelfTest", line)
        }
    }

    /** TIL-11: from the launcher's tile, open the waiting proposal's prompt; otherwise the app as usual. */
    private fun handle(intent: android.content.Intent?) {
        if (intent?.action != io.github.wotworth.tennis.tile.TileRows.ACTION_OPEN) return
        val id = intent.getStringExtra("proposal_id")?.toLongOrNull()
        val app = application as TennisApp
        app.scope.launch {
            val waiting = id != null && app.repo.dao.proposalsNow().any { it.id == id && it.state == "waiting" }
            nav.reset(if (waiting) io.github.wotworth.tennis.ui.Screen.Proposal(id!!) else io.github.wotworth.tennis.ui.Screen.Hub())
        }
    }

    /** DET-20: also check when the app comes to the front (Fitbit may have synced since). */
    override fun onResume() {
        super.onResume()
        val app = application as TennisApp
        app.scope.launch { runCatching { io.github.wotworth.tennis.health.DetectionRunner.run(app) } }
    }
}
