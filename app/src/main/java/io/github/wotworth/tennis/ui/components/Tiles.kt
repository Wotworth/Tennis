package io.github.wotworth.tennis.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens

/**
 * VIS-04: a flat, solid-color Metro tile with square corners, a label at the bottom-left and the
 * Windows Phone tilt on press. No shadow, ripple or rounded corners.
 */
@Composable
fun Tile(
    label: String,
    width: Dp,
    height: Dp,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val zpx = LocalZpx.current
    Box(
        modifier
            .size(width, height)
            .then(if (onClick != null) Modifier.press(description = label, onClick = onClick) else Modifier)
            .background(TennisTokens.Colors.tile)
            .padding(zpx(TennisTokens.Layout.tilePadding)),
    ) {
        content()
        TennisText(label, TennisTokens.Type.tileLabel, Modifier.align(Alignment.BottomStart), maxLines = 1)
    }
}

/** A square tile with a white Fluent glyph centered a little above the middle (VIS-06). */
@Composable
fun GlyphTile(label: String, @DrawableRes glyph: Int, size: Dp, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    Tile(label, size, size, modifier, onClick) {
        Image(
            painterResource(glyph),
            contentDescription = null,
            modifier = Modifier.align(Alignment.Center).padding(bottom = size * 0.08f).size(size * 0.34f),
        )
    }
}
