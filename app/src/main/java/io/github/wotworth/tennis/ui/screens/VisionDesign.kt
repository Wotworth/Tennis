package io.github.wotworth.tennis.ui.screens

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.painterResource
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.components.AppTitle
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.Units
import io.github.wotworth.tennis.vision.VisionSession
import io.github.wotworth.tennis.vision.VisionShot
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/*
 * Design v2 (Chris, 16 Nov): keep the Metro look, make choices easier to see and change. An
 * amendment to VIS-04 to VIS-08, approved by Chris: compact segment strips, a filter summary bar
 * that opens a flyout panel, flat toggles, legends for every colour scale, two-column stat grids,
 * selectors marked with a chevron, labelled app bar icons, and one colour per player.
 *
 * This file holds the parts and the VARIATIONS Chris chose between (docs/preview/v2). Chris, 17 Nov:
 * build them in, with the recommended picks: court B, shot A, trends A (VisionScreens uses
 * VisionFilterBar, CourtMapV2, ShotCardA and TrendSelectors; the variants stay for the previews).
 */

// ---- the parts --------------------------------------------------------------------------------

/** Design v2, item 1: one line of small square segments; selected = tile green, others dark grey. */
@Composable
fun SegmentStrip(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit = {}) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(zpx(t.segmentGap))) {
        options.forEach { (key, label) ->
            val on = key == selected
            Box(
                Modifier.height(zpx(t.segmentHeight))
                    .background(if (on) TennisTokens.Colors.tile else TennisTokens.Colors.segmentOff)
                    .press(description = label) { onSelect(key) }
                    .padding(horizontal = zpx(t.segmentPadX)),
                contentAlignment = Alignment.Center,
            ) { TennisText(label, TennisTokens.Type.segment, maxLines = 1) }
        }
    }
}

/** Design v2, item 2: the current choices on one line, with the Fluent filter icon. Tap: the flyout panel. */
@Composable
fun FilterBar(summary: String, onClick: () -> Unit = {}) {
    val zpx = LocalZpx.current
    Row(
        Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.filterBarHeight)).background(TennisTokens.Colors.segmentOff)
            .press(description = "filters: $summary", onClick = onClick).padding(horizontal = zpx(10f)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Glyph(R.drawable.fluent_filter, 18f)
        Spacer(Modifier.width(zpx(10f)))
        TennisText(summary, TennisTokens.Type.filterBar, Modifier.weight(1f), maxLines = 1, ellipsis = true)
        Glyph(R.drawable.fluent_chevron_down, 16f)
    }
}

/** Design v2, item 7: a choice that can be changed, marked with a chevron and an underline. */
@Composable
fun Selector(text: String, onClick: () -> Unit = {}) {
    val zpx = LocalZpx.current
    Column(Modifier.width(androidx.compose.foundation.layout.IntrinsicSize.Max).press(description = text, onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TennisText(text, TennisTokens.Type.listPrimary, maxLines = 1)
            Spacer(Modifier.width(zpx(4f)))
            Glyph(R.drawable.fluent_chevron_down, 16f)
        }
        Box(Modifier.fillMaxWidth().height(zpx(1f)).background(TennisTokens.Colors.secondary))
    }
}

/** Design v2, item 4: the flat rectangular Windows Phone toggle. */
@Composable
fun FlatToggle(label: String, on: Boolean, onChange: (Boolean) -> Unit = {}) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    Row(Modifier.fillMaxWidth().press(description = label) { onChange(!on) }.padding(vertical = zpx(6f)), verticalAlignment = Alignment.CenterVertically) {
        TennisText(label, TennisTokens.Type.body, Modifier.weight(1f))
        TennisText(if (on) "on" else "off", TennisTokens.Type.listSecondary)
        Spacer(Modifier.width(zpx(8f)))
        Canvas(Modifier.width(zpx(t.toggleWidth)).height(zpx(t.toggleHeight))) {
            val w = 2f * density
            drawRect(TennisTokens.Colors.primary, style = Stroke(w))
            val inner = 3f * density
            val fillW = size.width - 2 * inner
            if (on) drawRect(TennisTokens.Colors.tile, Offset(inner, inner), Size(fillW, size.height - 2 * inner))
            val thumbW = size.height * 0.55f
            val x = if (on) size.width - thumbW else 0f
            drawRect(TennisTokens.Colors.primary, Offset(x, 0f), Size(thumbW, size.height))
        }
    }
}

/** Design v2, item 5: a thin gradient bar with its two ends in mph or ft. */
@Composable
fun GradientLegend(label: String, low: Color, high: Color, lowText: String, highText: String) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        TennisText(label, TennisTokens.Type.listSecondary, Modifier.width(zpx(if (label.length > 10) 110f else 64f)), maxLines = 1)
        TennisText(lowText, TennisTokens.Type.listSecondary, maxLines = 1)
        Spacer(Modifier.width(zpx(6f)))
        Canvas(Modifier.weight(1f).height(zpx(t.legendBarHeight))) {
            drawRect(Brush.horizontalGradient(listOf(low, high)))
        }
        Spacer(Modifier.width(zpx(6f)))
        TennisText(highText, TennisTokens.Type.listSecondary, maxLines = 1)
    }
}

/** Design v2, item 6: stats two to a row, number large and label small. */
@Composable
fun StatGrid(items: List<Pair<String, String>>, columns: Int = 2) {
    val zpx = LocalZpx.current
    items.chunked(columns).forEach { row ->
        Row(Modifier.fillMaxWidth().padding(bottom = zpx(7f))) {
            row.forEach { (value, label) ->
                Column(Modifier.weight(1f).padding(end = zpx(8f))) {
                    TennisText(value, TennisTokens.Type.statNumber, maxLines = 1)
                    TennisText(label, TennisTokens.Type.statLabel, maxLines = 2)
                }
            }
            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

/** Design v2, item 8: app bar icons with a short label under each, no "…" for actions. */
data class LabeledAction(@DrawableRes val glyph: Int, val label: String, val onClick: () -> Unit = {})

@Composable
fun LabeledAppBar(actions: List<LabeledAction>, modifier: Modifier = Modifier) {
    val zpx = LocalZpx.current
    Row(
        modifier.fillMaxWidth().background(TennisTokens.Colors.appBar).navigationBarsPadding().padding(vertical = zpx(6f)),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        actions.forEach { a ->
            Column(Modifier.press(description = a.label, onClick = a.onClick).padding(horizontal = zpx(8f)), horizontalAlignment = Alignment.CenterHorizontally) {
                Glyph(a.glyph, 22f)
                Spacer(Modifier.height(zpx(3f)))
                TennisText(a.label, TennisTokens.Type.tileLabelSmall)
            }
        }
    }
}

@Composable
fun Glyph(@DrawableRes id: Int, sizeZpx: Float, tint: Color = TennisTokens.Colors.primary) {
    val zpx = LocalZpx.current
    Image(painterResource(id), contentDescription = null, colorFilter = ColorFilter.tint(tint), modifier = Modifier.size(zpx(sizeZpx)))
}

/** A small square of a player's colour, before their name. */
@Composable
fun PlayerSwatch(c: Color) {
    val zpx = LocalZpx.current
    Box(Modifier.size(zpx(10f)).background(c))
}

// ---- player colours (item 9) --------------------------------------------------------------------

object PlayerColour {
    fun isMe(v: VisionSession, s: VisionShot, answer: String?) = v.who(s.hitter, answer) == "you"
    fun base(me: Boolean) = if (me) TennisTokens.Colors.me else TennisTokens.Colors.opponent
    /** f: 0 (slow, little spin) to 1 (fast, much spin): the player's own colour, dark to light. */
    fun shade(me: Boolean, f: Float): Color = if (me) lerp(TennisTokens.Colors.meLow, TennisTokens.Colors.meHigh, f)
        else lerp(TennisTokens.Colors.opponentLow, TennisTokens.Colors.opponentHigh, f)
    fun speedF(ms: Double?): Float {
        val t = TennisTokens.Vision
        return (((ms ?: 0.0) * Units.MPH_PER_MS - t.speedLowMph) / (t.speedHighMph - t.speedLowMph)).toFloat().coerceIn(0f, 1f)
    }
    fun spinF(effectM: Double?): Float =
        ((-(effectM ?: 0.0)) * Units.FT_PER_M / TennisTokens.Vision.spinEffectHighFt).toFloat().coerceIn(0f, 1f)
}

/** How the court map shows speed or spin on top of the player colours. */
enum class CourtStyle { Shades, Size }

/** The court seen from above with each bounce: player colour, shaded or sized by speed or spin. */
@Composable
fun CourtMapV2(v: VisionSession, shots: List<VisionShot>, answer: String?, bySpin: Boolean, style: CourtStyle, heightZpx: Float,
               onShot: ((VisionShot) -> Unit)? = null) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    val lengthM = 2 * (Court.HALF_LENGTH + t.courtMarginM)
    val widthM = 2 * (Court.HALF_DOUBLES + t.courtMarginM)
    var mapping by remember { mutableStateOf<(Double, Double) -> Offset>({ _, _ -> Offset.Zero }) }
    val tap = if (onShot == null) Modifier else Modifier.pointerInput(shots) {
        detectTapGestures { p ->
            val near = shots.minByOrNull { sh -> (mapping(sh.bounce!![0], sh.bounce[1]) - p).getDistance() }
            if (near != null && (mapping(near.bounce!![0], near.bounce[1]) - p).getDistance() < zpx(t.spotTapRadius).toPx()) onShot(near)
        }
    }
    Canvas(Modifier.fillMaxWidth().height(zpx(heightZpx)).then(tap)) {
        // the court runs up the screen: court x -> screen y, court y -> screen x
        val pad = zpx(t.courtSidePadding).toPx()
        val s = minOf((size.width - 2 * pad) / widthM.toFloat(), (size.height - 2 * pad) / lengthM.toFloat())
        val cx = size.width / 2;  val cy = size.height / 2
        val map = { x: Double, y: Double -> Offset(cx + (y * s).toFloat(), cy - (x * s).toFloat()) }
        mapping = map
        drawCourtTopDown(map, s)
        shots.forEach { sh ->
            val me = PlayerColour.isMe(v, sh, answer)
            val f = if (bySpin) PlayerColour.spinF(sh.spinEffect) else PlayerColour.speedF(sh.speedContact)
            val p = map(sh.bounce!![0], sh.bounce[1])
            when (style) {
                CourtStyle.Shades -> drawCircle(PlayerColour.shade(me, f), zpx(t.spotRadius).toPx(), p)
                CourtStyle.Size -> drawCircle(PlayerColour.base(me), zpx(t.spotMinRadius + f * (t.spotMaxRadius - t.spotMinRadius)).toPx(), p)
            }
        }
    }
}

/** Legends under the court map: one gradient per player (shades), or the dot sizes (size). */
@Composable
fun CourtLegends(bySpin: Boolean, style: CourtStyle, players: List<Boolean>) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Vision
    val lo = if (bySpin) "no spin" else "${t.speedLowMph.roundToInt()} mph"
    val hi = if (bySpin) "${t.spinEffectHighFt.roundToInt()} ft shorter" else "${t.speedHighMph.roundToInt()} mph"
    when (style) {
        CourtStyle.Shades -> players.forEach { me ->
            GradientLegend(if (me) "you" else "opponent", PlayerColour.shade(me, 0f), PlayerColour.shade(me, 1f), lo, hi)
            Spacer(Modifier.height(zpx(4f)))
        }
        CourtStyle.Size -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
                players.forEach { me ->
                    PlayerSwatch(PlayerColour.base(me)); Spacer(Modifier.width(zpx(4f)))
                    TennisText(if (me) "you" else "opponent", TennisTokens.Type.listSecondary); Spacer(Modifier.width(zpx(14f)))
                }
            }
            Spacer(Modifier.height(zpx(4f)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                TennisText(if (bySpin) "ft shorter" else "speed", TennisTokens.Type.listSecondary, Modifier.width(zpx(64f)), maxLines = 1)
                listOf(0f to lo.substringBefore(" "), 0.5f to (if (bySpin) "${(t.spinEffectHighFt / 2).roundToInt()}" else "${((t.speedLowMph + t.speedHighMph) / 2).roundToInt()}"), 1f to hi).forEach { (f, label) ->
                    Canvas(Modifier.size(zpx(2 * t.spotMaxRadius + 2f))) {
                        drawCircle(TennisTokens.Colors.secondary, zpx(t.spotMinRadius + f * (t.spotMaxRadius - t.spotMinRadius)).toPx())
                    }
                    Spacer(Modifier.width(zpx(3f)))
                    TennisText(label, TennisTokens.Type.listSecondary, maxLines = 1)
                    Spacer(Modifier.width(zpx(8f)))
                }
            }
        }
    }
}

// ---- frames for the variations --------------------------------------------------------------------

private val PEEK = TennisTokens.Role(42f, TennisTokens.Weight.Light, -0.01f, TennisTokens.Case.Lowercase, TennisTokens.Tone.Secondary)

/** A pivot page as the session shows it: small title, this pivot's header, the next one peeking. */
@Composable
fun PivotFrame(title: String, header: String, next: String?, bar: (@Composable () -> Unit)? = null, overlay: (@Composable () -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val zpx = LocalZpx.current
    val l = TennisTokens.Layout
    Box(Modifier.fillMaxSize().background(TennisTokens.Colors.background).statusBarsPadding()) {
        Column(Modifier.fillMaxSize()) {
            AppTitle(text = title)
            Row(Modifier.padding(start = zpx(l.pageSideMargin))) {
                TennisText(header, TennisTokens.Type.pivotHeader, maxLines = 1)
                if (next != null) { Spacer(Modifier.width(zpx(18f))); TennisText(next, PEEK, maxLines = 1) }
            }
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = zpx(l.pageSideMargin)).padding(top = zpx(10f))) {
                content()
                Spacer(Modifier.height(zpx(l.appBarHeight + 16f)))
            }
        }
        if (bar != null) Box(Modifier.align(Alignment.BottomCenter)) { bar() }
        if (overlay != null) overlay()
    }
}

/** Design v2, item 2: the flyout: full width, square, slid down from the top (drawn open). */
@Composable
fun FilterFlyout(title: String, content: @Composable ColumnScope.() -> Unit) {
    val zpx = LocalZpx.current
    Box(Modifier.fillMaxSize().background(Color(0xB3000000))) {
        Column(Modifier.fillMaxWidth().background(TennisTokens.Colors.panel).statusBarsPadding().padding(zpx(TennisTokens.Layout.pageSideMargin))) {
            TennisText(title, TennisTokens.Type.sectionHeader)
            Spacer(Modifier.height(zpx(10f)))
            content()
            Spacer(Modifier.height(zpx(6f)))
            Row(horizontalArrangement = Arrangement.spacedBy(zpx(8f))) {
                Box(Modifier.background(TennisTokens.Colors.tile).padding(horizontal = zpx(18f), vertical = zpx(8f))) { TennisText("done", TennisTokens.Type.button) }
                Box(Modifier.background(TennisTokens.Colors.segmentOff).padding(horizontal = zpx(18f), vertical = zpx(8f))) { TennisText("reset", TennisTokens.Type.button) }
            }
        }
    }
}

@Composable
private fun FlyoutRow(label: String, content: @Composable () -> Unit) {
    val zpx = LocalZpx.current
    TennisText(label, TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(zpx(4f)))
    content()
    Spacer(Modifier.height(zpx(10f)))
}

// ---- the variations Chris chooses between ------------------------------------------------------------

val TYPE_OPTIONS = listOf("all" to "all", "serve" to "serves", "forehand" to "forehands", "backhand" to "backhands")
val COLOUR_OPTIONS = listOf("speed" to "speed", "spin" to "spin effect")

private fun whoOptions(v: VisionSession, answer: String?): List<Pair<String, String>> =
    listOf("all" to "everyone") + v.shots.map { it.hitter }.distinct().sorted().map { it to v.who(it, answer) }

private fun summaryOf(type: String, colour: String, who: String, v: VisionSession, answer: String?): String = listOf(
    TYPE_OPTIONS.first { it.first == type }.second,
    COLOUR_OPTIONS.first { it.first == colour }.second,
    if (who == "all") "everyone" else v.who(who, answer),
).joinToString(" · ")

/** Court map, variation A: three segment strips, player shades, a legend per player. */
@Composable
fun CourtVariantA(v: VisionSession, answer: String?, type: String, colour: String, who: String) {
    val zpx = LocalZpx.current
    val shots = v.shots.filter { it.bounce != null && (type == "all" || it.type == type) && (who == "all" || it.hitter == who) }
    PivotFrame(visionDay(v) + " · sample", "court", "shots") {
        SegmentStrip(TYPE_OPTIONS, type); Spacer(Modifier.height(zpx(4f)))
        SegmentStrip(COLOUR_OPTIONS.map { it.first to "by ${it.second}" }, colour); Spacer(Modifier.height(zpx(4f)))
        SegmentStrip(whoOptions(v, answer), who)
        Spacer(Modifier.height(zpx(6f)))
        CourtMapV2(v, shots, answer, colour == "spin", CourtStyle.Shades, TennisTokens.Vision.courtMapHeight)
        Spacer(Modifier.height(zpx(6f)))
        CourtLegends(colour == "spin", CourtStyle.Shades, players(v, shots, answer))
        TennisText("${shots.size} bounces. Tap one for that shot.", TennisTokens.Type.listSecondary)
    }
}

/** Court map, variation B: one filter bar opening a flyout; the map gets the space; player shades. */
@Composable
fun CourtVariantB(v: VisionSession, answer: String?, type: String, colour: String, who: String, open: Boolean = false) {
    val zpx = LocalZpx.current
    val shots = v.shots.filter { it.bounce != null && (type == "all" || it.type == type) && (who == "all" || it.hitter == who) }
    PivotFrame(visionDay(v) + " · sample", "court", "shots", overlay = if (open) ({ CourtFlyout(v, answer, type, colour, who) }) else null) {
        FilterBar(summaryOf(type, colour, who, v, answer))
        Spacer(Modifier.height(zpx(6f)))
        CourtMapV2(v, shots, answer, colour == "spin", CourtStyle.Shades, TennisTokens.Vision.courtMapHeight + 110f)
        Spacer(Modifier.height(zpx(6f)))
        CourtLegends(colour == "spin", CourtStyle.Shades, players(v, shots, answer))
        TennisText("${shots.size} bounces. Tap one for that shot.", TennisTokens.Type.listSecondary)
    }
}

/** Court map, variation C: the filter bar; player colour fixed, speed or spin as dot size. */
@Composable
fun CourtVariantC(v: VisionSession, answer: String?, type: String, colour: String, who: String) {
    val zpx = LocalZpx.current
    val shots = v.shots.filter { it.bounce != null && (type == "all" || it.type == type) && (who == "all" || it.hitter == who) }
    PivotFrame(visionDay(v) + " · sample", "court", "shots") {
        FilterBar(summaryOf(type, colour, who, v, answer))
        Spacer(Modifier.height(zpx(6f)))
        CourtMapV2(v, shots, answer, colour == "spin", CourtStyle.Size, TennisTokens.Vision.courtMapHeight + 110f)
        Spacer(Modifier.height(zpx(6f)))
        CourtLegends(colour == "spin", CourtStyle.Size, players(v, shots, answer))
        Spacer(Modifier.height(zpx(4f)))
        TennisText("${shots.size} bounces. Tap one for that shot.", TennisTokens.Type.listSecondary)
    }
}

private fun players(v: VisionSession, shots: List<VisionShot>, answer: String?): List<Boolean> =
    shots.map { PlayerColour.isMe(v, it, answer) }.distinct().sortedDescending()

@Composable
private fun CourtFlyout(v: VisionSession, answer: String?, type: String, colour: String, who: String) {
    val app = LocalApp.current
    FilterFlyout("court filters · kept across court, shots and rallies") {
        FlyoutRow("shot type") { SegmentStrip(TYPE_OPTIONS, type) }
        FlyoutRow("colour by") { SegmentStrip(COLOUR_OPTIONS, colour) }
        FlyoutRow("player") { SegmentStrip(whoOptions(v, answer), who) }
        FlatToggle("opponent's stats", v.id in app.prefs.opponentStatsOn)
    }
}

/** Shot card, variation A: side view in the hitter's colour, then a two-column stat grid; labelled app bar. */
@Composable
fun ShotVariantA(v: VisionSession, s: VisionShot, answer: String?) {
    val zpx = LocalZpx.current
    val me = PlayerColour.isMe(v, s, answer)
    PivotFrame("shot ${s.rally}·${s.index}", "shot", null, bar = { LabeledAppBar(shotActions()) }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PlayerSwatch(PlayerColour.base(me)); Spacer(Modifier.width(zpx(6f)))
            TennisText(shotLine(s, v.who(s.hitter, answer)), TennisTokens.Type.listSecondary)
        }
        Spacer(Modifier.height(zpx(6f)))
        v.trajectory(s.rally, s.index)?.let { SideView(it, s, PlayerColour.base(me)) }
        Spacer(Modifier.height(zpx(10f)))
        StatGrid(shotStats(s))
    }
}

/** Shot card, variation B: a headline row (speed, call), then the stats in three small groups. */
@Composable
fun ShotVariantB(v: VisionSession, s: VisionShot, answer: String?) {
    val zpx = LocalZpx.current
    val me = PlayerColour.isMe(v, s, answer)
    PivotFrame("shot ${s.rally}·${s.index}", "shot", null, bar = { LabeledAppBar(shotActions()) }) {
        Row(verticalAlignment = Alignment.Bottom) {
            TennisText(Units.mph(s.speedContact), TennisTokens.Type.tileNumber)
            Spacer(Modifier.width(zpx(10f)))
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    PlayerSwatch(PlayerColour.base(me)); Spacer(Modifier.width(zpx(5f)))
                    TennisText("${v.who(s.hitter, answer)} · ${s.type}", TennisTokens.Type.body)
                }
                TennisText("${s.call} · rally ${s.rally}, shot ${s.index}", TennisTokens.Type.listSecondary)
            }
        }
        Spacer(Modifier.height(zpx(6f)))
        v.trajectory(s.rally, s.index)?.let { SideView(it, s, PlayerColour.base(me), caption = false) }
        TennisText("solid: real path · dashed: no spin", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(10f)))
        val all = shotStats(s).associate { it.second to it.first }
        Group("flight"); StatGrid(listOfNotNull(pick(all, "launch angle"), pick(all, "net clearance"), pick(all, "highest point"), pick(all, "at the bounce")), 2)
        Group("bounce"); StatGrid(listOfNotNull(pick(all, "inside the baseline"), pick(all, "bounce ±"), pick(all, "kick off the court"), pick(all, "call")), 2)
        Group("spin"); StatGrid(listOfNotNull(pick(all, "spin effect on the bounce"), pick(all, "spin"), pick(all, "topspin / sidespin"), pick(all, "spin rate")), 2)
        TennisText("measurement confidence ${s.confidence?.let { "${(it * 100).roundToInt()}%" } ?: "–"}", TennisTokens.Type.listSecondary)
    }
}

@Composable
private fun Group(name: String) {
    val zpx = LocalZpx.current
    TennisText(name, TennisTokens.Type.sectionHeader)
    Spacer(Modifier.height(zpx(4f)))
}

private fun pick(m: Map<String, String>, label: String) = m[label]?.let { it to label }

private fun shotActions() = listOf(
    LabeledAction(R.drawable.fluent_arrow_up, "previous"),
    LabeledAction(R.drawable.fluent_arrow_down, "next"),
    LabeledAction(R.drawable.fluent_flag, "looks wrong"),
)

/** The shot card's figures, number first, label second (the order variation A shows them in). */
fun shotStats(s: VisionShot): List<Pair<String, String>> = listOfNotNull(
    Units.mph(s.speedContact) to "speed at contact",
    (s.speedBounce?.let { Units.mph(it) } ?: "–") to "at the bounce",
    (s.launchDeg?.let { "%.1f°".format(Locale.US, it) } ?: "–") to "launch angle",
    Units.inches(s.netClearance) to "net clearance",
    Units.ft(s.apex) to "highest point",
    s.call to "call",
    Units.ft(s.depth) to "inside the baseline",
    "± ${Units.inches(s.bounceSd)}" to "bounce ±",
    (s.spinEffect?.let { "${Units.ft(abs(it))} ${if (it < 0) "shorter" else "longer"}" } ?: "–") to "spin effect on the bounce",
    (s.spinLabel.ifBlank { "–" }) to "spin",
    (s.rpm?.let { Units.rpm(it, s.rpmSd) } ?: "–") to "spin rate",
    spinSplit(s).replace("topspin ", "").replace("slice ", "").replace(" · sidespin ", " / ") to "topspin / sidespin",
    (s.kickAngleDeg?.let { "%.0f°".format(Locale.US, it) } ?: "–") to "kick off the court",
    (s.confidence?.let { "${(it * 100).roundToInt()}%" } ?: "–") to "confidence",
)

/** Trends, variation A: the line of choices as selectors (chevron, underline) that open the flyout. */
@Composable
fun TrendsVariantA(racquet: String?, open: Boolean = false) {
    val zpx = LocalZpx.current
    PivotFrame("tennis", "trends", null, overlay = if (open) ({ TrendsFlyout(racquet) }) else null) {
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
            Selector("forehand")
            Selector("you")
            if (racquet != null) Selector(racquet.lowercase())
        }
        Spacer(Modifier.height(zpx(4f)))
        TennisText("Synthetic trend for the preview. Tap a choice to change it.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        TrendCharts()
    }
}

/** Trends, variation B: the same filter bar as the court map, plus a strip for the shot type. */
@Composable
fun TrendsVariantB(racquet: String?) {
    val zpx = LocalZpx.current
    PivotFrame("tennis", "trends", null) {
        FilterBar(listOfNotNull("forehands", "you", racquet?.lowercase()).joinToString(" · "))
        Spacer(Modifier.height(zpx(6f)))
        SegmentStrip(listOf("serve" to "serves", "forehand" to "forehands", "backhand" to "backhands", "volley" to "volleys"), "forehand")
        Spacer(Modifier.height(zpx(4f)))
        TennisText("Synthetic trend for the preview.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        TrendCharts()
    }
}

@Composable
private fun TrendCharts() {
    val app = LocalApp.current
    val zpx = LocalZpx.current
    val d = io.github.wotworth.tennis.ui.appData()
    val pts = app.vision.trends(app.prefs.visionSample)
    if (pts.size < 2) return
    val racquet = d.racquet(app.prefs.selectedRacquet ?: -1) ?: d.active.firstOrNull()
    val jobs = d.jobs.filter { it.racquetId == racquet?.id }
    TrendChart("spin effect, ft shorter", pts.map { it.epochDay to -it.forehandSpinEffect * Units.FT_PER_M }, jobs)
    Spacer(Modifier.height(zpx(10f)))
    TrendChart("depth, ft inside the baseline", pts.map { it.epochDay to it.forehandDepth * Units.FT_PER_M }, jobs)
}

@Composable
private fun TrendsFlyout(racquet: String?) {
    FilterFlyout("trend choices") {
        FlyoutRow("shot type") { SegmentStrip(listOf("serve" to "serves", "forehand" to "forehands", "backhand" to "backhands", "volley" to "volleys"), "forehand") }
        FlyoutRow("player") { SegmentStrip(listOf("you" to "you", "opponents" to "opponents"), "you") }
        FlyoutRow("racquet") { SegmentStrip(listOfNotNull("any" to "any racquet", racquet?.let { it to it.lowercase() }), racquet ?: "any") }
        FlyoutRow("measures") { SegmentStrip(listOf("spin" to "spin effect", "depth" to "depth", "speed" to "speed", "net" to "net clearance"), "spin") }
    }
}

// ---- built in (Chris, 17 Nov: court B, shot A, trends A) ---------------------------------------------

/** The data pages' shared choices (court, shots): kept while the session is open. */
class VisionFilter {
    var type by mutableStateOf(VisionDefaults.courtType)
    var colour by mutableStateOf(VisionDefaults.courtColour)
    var who by mutableStateOf("all")
    fun reset() { type = VisionDefaults.courtType;  colour = VisionDefaults.courtColour;  who = "all" }
    fun keep(s: VisionShot) = (type == "all" || s.type == type) && (who == "all" || s.hitter == who)
}

/** Court B's filter bar: one line of the current choices; tap for the flyout with every option. */
@Composable
fun VisionFilterBar(v: VisionSession, answer: String?, f: VisionFilter) {
    val app = LocalApp.current
    val o = io.github.wotworth.tennis.ui.components.LocalOverlays.current
    FilterBar(summaryOf(f.type, f.colour, f.who, v, answer)) {
        o.panel("filters · kept across court and shots", onReset = { f.reset() }) {
            FlyoutRow("shot type") { SegmentStrip(TYPE_OPTIONS, f.type) { f.type = it } }
            FlyoutRow("colour by") { SegmentStrip(COLOUR_OPTIONS, f.colour) { f.colour = it } }
            FlyoutRow("player") { SegmentStrip(whoOptions(v, answer), f.who) { f.who = it } }
            if (!v.sample || answer != null) FlatToggle("opponent's stats", v.id in app.prefs.opponentStatsOn) { app.prefs.showOpponentStats(v.id, it) }
        }
    }
}

/** Court B on a real session: the filter bar, the map (tap a bounce for its shot), a legend per player. */
@Composable
fun CourtB(v: VisionSession, answer: String?, f: VisionFilter, onShot: (VisionShot) -> Unit) {
    val zpx = LocalZpx.current
    val shots = v.shots.filter { it.bounce != null && f.keep(it) }
    VisionFilterBar(v, answer, f)
    Spacer(Modifier.height(zpx(6f)))
    CourtMapV2(v, shots, answer, f.colour == "spin", CourtStyle.Shades, TennisTokens.Vision.courtMapHeight + 110f, onShot)
    Spacer(Modifier.height(zpx(6f)))
    CourtLegends(f.colour == "spin", CourtStyle.Shades, players(v, shots, answer))
    TennisText("${shots.size} bounces. Tap one for that shot.", TennisTokens.Type.listSecondary)
}

/** Shot A on a real shot: swatch and line, the side view in the hitter's colour, the two-column grid. */
@Composable
fun ShotCardA(v: VisionSession, s: VisionShot, answer: String?) {
    val zpx = LocalZpx.current
    val me = PlayerColour.isMe(v, s, answer)
    Row(verticalAlignment = Alignment.CenterVertically) {
        PlayerSwatch(PlayerColour.base(me)); Spacer(Modifier.width(zpx(6f)))
        TennisText(shotLine(s, v.who(s.hitter, answer)), TennisTokens.Type.listSecondary)
    }
    Spacer(Modifier.height(zpx(6f)))
    v.trajectory(s.rally, s.index)?.let { SideView(it, s, PlayerColour.base(me)) }
    Spacer(Modifier.height(zpx(10f)))
    StatGrid(shotStats(s))
}

/** A shots-list row with the hitter's colour before it. */
@Composable
fun ShotRow(v: VisionSession, s: VisionShot, answer: String?, onClick: () -> Unit) {
    val zpx = LocalZpx.current
    Row(verticalAlignment = Alignment.Top) {
        Box(Modifier.padding(top = zpx(9f))) { PlayerSwatch(PlayerColour.base(PlayerColour.isMe(v, s, answer))) }
        Spacer(Modifier.width(zpx(8f)))
        io.github.wotworth.tennis.ui.components.TextRow("rally ${s.rally} · shot ${s.index}", shotLine(s, v.who(s.hitter, answer)), onClick = onClick)
    }
}
