package io.github.wotworth.tennis.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisTokens

data class BarButton(@DrawableRes val glyph: Int, val label: String, val enabled: Boolean = true, val onClick: () -> Unit)

/**
 * NAV-08: the Windows Phone application bar: round glyph buttons centred along the bottom, and
 * the "…" at the right edge (settings). Transparent over black, as in WP's dark theme.
 */
@Composable
fun AppBar(buttons: List<BarButton>, modifier: Modifier = Modifier, onMore: (() -> Unit)? = null) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(modifier.fillMaxWidth().background(TennisTokens.Colors.appBar).navigationBarsPadding().height(zpx(l.appBarHeight))) {
        Row(Modifier.align(Alignment.Center), horizontalArrangement = Arrangement.spacedBy(zpx(22f)), verticalAlignment = Alignment.CenterVertically) {
            buttons.forEach { RoundButton(it) }
        }
        if (onMore != null) {
            Box(
                Modifier.align(Alignment.CenterEnd).padding(end = zpx(6f)).size(zpx(l.appBarHeight)).press(description = "settings", onClick = onMore),
                contentAlignment = Alignment.Center,
            ) {
                Image(painterResource(R.drawable.fluent_more_horizontal), contentDescription = null, modifier = Modifier.size(zpx(l.appBarDotsSize * 0.6f)))
            }
        }
    }
}

@Composable
fun RoundButton(b: BarButton) {
    val zpx = LocalZpx.current
    val d = zpx(TennisTokens.Layout.appBarButton)
    val color = if (b.enabled) TennisTokens.Colors.primary else TennisTokens.Colors.disabled
    Box(
        Modifier.size(d).then(if (b.enabled) Modifier.press(description = b.label, onClick = b.onClick) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        val stroke = zpx(TennisTokens.Layout.ringStroke)
        Canvas(Modifier.size(d)) {
            val w = stroke.toPx()
            drawCircle(color, radius = size.minDimension / 2 - w / 2, style = Stroke(w))
        }
        Image(painterResource(b.glyph), contentDescription = null, colorFilter = ColorFilter.tint(color), modifier = Modifier.size(d * 0.5f))
    }
}
