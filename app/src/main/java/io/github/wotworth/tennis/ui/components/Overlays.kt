package io.github.wotworth.tennis.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/** What sits above the screens: a Windows Phone context menu or message box. */
class Overlays {
    sealed interface Overlay
    /** A long-press menu: lowercase items on the chrome panel, the screen dimmed behind it. */
    data class Menu(val items: List<Pair<String, () -> Unit>>) : Overlay
    /** A message box: title, text, and two buttons. */
    data class Message(val title: String, val text: String, val ok: String, val cancel: String?, val onOk: () -> Unit) : Overlay

    var current by mutableStateOf<Overlay?>(null)
        private set
    fun menu(vararg items: Pair<String, () -> Unit>) { current = Menu(items.toList()) }
    fun confirm(title: String, text: String, ok: String, onOk: () -> Unit) { current = Message(title, text, ok, "cancel", onOk) }
    fun tell(title: String, text: String) { current = Message(title, text, "ok", null) {} }
    fun dismiss() { current = null }
}

val LocalOverlays = staticCompositionLocalOf { Overlays() }

@Composable
fun OverlayHost(o: Overlays) {
    val cur = o.current ?: return
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(
        Modifier.fillMaxSize().background(Color(0x99000000)).press(tilt = false, onClick = { o.dismiss() }),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .background(TennisTokens.Colors.panel)
                .statusBarsPadding()
                .padding(horizontal = zpx(l.pageSideMargin), vertical = zpx(14f))
                // Taps on the panel itself don't close it.
                .press(tilt = false, onClick = {}),
        ) {
            when (cur) {
                is Overlays.Menu -> cur.items.forEach { (label, action) ->
                    TennisText(label, TennisTokens.Type.menuItem, Modifier.fillMaxWidth().press(description = label) { o.dismiss(); action() }.padding(vertical = zpx(9f)))
                }
                is Overlays.Message -> {
                    TennisText(cur.title, TennisTokens.Type.listPrimary)
                    Spacer(Modifier.height(zpx(8f)))
                    TennisText(cur.text, TennisTokens.Type.body)
                    Spacer(Modifier.height(zpx(16f)))
                    Row(horizontalArrangement = Arrangement.spacedBy(zpx(8f))) {
                        MetroButton(cur.ok, Modifier.weight(1f)) { o.dismiss(); cur.onOk() }
                        if (cur.cancel != null) MetroButton(cur.cancel, Modifier.weight(1f)) { o.dismiss() } else Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

/** The Windows Phone button: a white-outlined rectangle with its label, no fill. */
@Composable
fun MetroButton(label: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val zpx = LocalZpx.current
    val color = if (enabled) TennisTokens.Colors.primary else TennisTokens.Colors.disabled
    Box(
        modifier
            .then(if (enabled) Modifier.press(description = label, onClick = onClick) else Modifier)
            .border(zpx(2f), color)
            .padding(vertical = zpx(9f), horizontal = zpx(10f)),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.text.BasicText(label, style = io.github.wotworth.tennis.ui.theme.textStyleFor(TennisTokens.Type.button).copy(color = color))
    }
}
