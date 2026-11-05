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
        setContent { AppRoot(application as TennisApp) }
    }

    /** DET-20: also check when the app comes to the front (Fitbit may have synced since). */
    override fun onResume() {
        super.onResume()
        val app = application as TennisApp
        app.scope.launch { runCatching { io.github.wotworth.tennis.health.DetectionRunner.run(app) } }
    }
}
