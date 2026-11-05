package io.github.wotworth.tennis

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import io.github.wotworth.tennis.ui.screens.PrivacyScreen
import io.github.wotworth.tennis.ui.theme.TennisTheme

/** DET-02: the page Health Connect opens from its permission screen ("privacy policy"). */
class PrivacyActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        setContent { TennisTheme { PrivacyScreen() } }
    }
}
