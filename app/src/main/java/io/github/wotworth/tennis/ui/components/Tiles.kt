package io.github.wotworth.tennis.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.textStyleFor

/**
 * VIS-04: a flat, solid-color Metro tile with square corners, a label at the bottom-left and the
 * Windows Phone tilt on press. No shadow, ripple or rounded corners.
 */
@Composable
fun Tile(
    label: String?,
    width: Dp,
    height: Dp,
    modifier: Modifier = Modifier,
    description: String? = label,
    onClick: (() -> Unit)? = null,
    background: (@Composable BoxScope.() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val zpx = LocalZpx.current
    Box(
        modifier
            .size(width, height)
            .then(if (onClick != null) Modifier.press(description = description, onClick = onClick) else Modifier)
            .background(TennisTokens.Colors.tile),
    ) {
        background?.invoke(this)
        Box(Modifier.fillMaxSize().padding(zpx(TennisTokens.Layout.tilePadding))) {
            content()
            if (label != null) TennisText(label, TennisTokens.Type.tileLabel, Modifier.align(Alignment.BottomStart), maxLines = 1)
        }
    }
}

/** A tile with a white Fluent glyph in the middle (VIS-06). Small tiles have no label, as on WP. */
@Composable
fun GlyphTile(label: String, @DrawableRes glyph: Int, size: Dp, modifier: Modifier = Modifier, showLabel: Boolean = true, onClick: (() -> Unit)? = null) {
    Tile(if (showLabel) label else null, size, size, modifier, description = label, onClick = onClick) {
        Image(
            painterResource(glyph),
            contentDescription = null,
            modifier = Modifier.align(Alignment.Center).padding(bottom = if (showLabel) size * 0.08f else size * 0f).size(size * if (showLabel) 0.34f else 0.46f),
        )
    }
}

/** NAV-02: a big number with a small label under it, WP style ("14.5" over "hours on strings"). */
@Composable
fun NumberTile(
    number: String,
    label: String,
    width: Dp,
    height: Dp,
    modifier: Modifier = Modifier,
    small: Boolean = false,
    onClick: (() -> Unit)? = null,
    extra: (@Composable BoxScope.() -> Unit)? = null,
) {
    val zpx = LocalZpx.current
    Tile(if (small) null else label, width, height, modifier, description = "$number $label", onClick = onClick) {
        extra?.invoke(this)
        if (small) {
            Column(Modifier.align(Alignment.BottomStart)) {
                FitText(number, TennisTokens.Type.tileNumberSmall)
                TennisText(label, TennisTokens.Type.tileLabelSmall, maxLines = 1)
            }
        } else {
            FitText(number, TennisTokens.Type.tileNumber, Modifier.align(Alignment.TopStart).padding(bottom = zpx(18f)))
        }
    }
}

/** One line of text, shrunk until it fits the width (NFR-03: headline text is never cut). */
@Composable
fun FitText(text: String, role: TennisTokens.Role, modifier: Modifier = Modifier) {
    val base = textStyleFor(role)
    androidx.compose.foundation.layout.BoxWithConstraints(modifier) {
        val measurer = androidx.compose.ui.text.rememberTextMeasurer()
        val maxPx = constraints.maxWidth
        var size = base.fontSize
        var style = base
        var tries = 0
        while (tries < 8 && measurer.measure(text, style, maxLines = 1, softWrap = false).size.width > maxPx) {
            size *= 0.88f
            style = base.copy(fontSize = size, lineHeight = size)
            tries++
        }
        BasicText(text, style = style, maxLines = 1, softWrap = false, overflow = TextOverflow.Clip)
    }
}

/**
 * STA-02 in miniature: feel ratings as a white line on the tile, oldest left. Drawn only with two
 * or more ratings. The scale is fixed 1 to 5 so the slope means something.
 */
@Composable
fun Sparkline(values: List<Int>, modifier: Modifier = Modifier) {
    if (values.size < 2) return
    val zpx = LocalZpx.current
    val stroke = zpx(2f)
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val pts = values.mapIndexed { i, v -> Offset(w * i / (values.size - 1), h - h * (v - 1) / 4f) }
        val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) } }
        drawPath(path, TennisTokens.Colors.primary, style = Stroke(stroke.toPx(), cap = StrokeCap.Square, join = StrokeJoin.Miter))
        drawCircle(TennisTokens.Colors.primary, radius = stroke.toPx() * 1.4f, center = pts.last())
    }
}

/** Two lines of plain text on a wide tile, under the label row (the current setup). */
@Composable
fun BoxScope.TileLines(lines: List<String>) {
    Column(Modifier.align(Alignment.TopStart).fillMaxWidth().padding(bottom = LocalZpx.current(20f))) {
        lines.forEachIndexed { i, l ->
            TennisText(l, if (i == 0) TennisTokens.Type.tileTextLarge else TennisTokens.Type.tileText, maxLines = 2)
            if (i == 0) Box(Modifier.height(LocalZpx.current(4f)))
        }
    }
}
