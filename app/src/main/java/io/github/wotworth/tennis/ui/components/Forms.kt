package io.github.wotworth.tennis.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.ui.theme.textStyleFor

/** A form label: small grey text over its control (NAV-07). */
@Composable
fun FieldLabel(text: String) {
    TennisText(text, TennisTokens.Type.listSecondary)
    Spacer(Modifier.height(LocalZpx.current(4f)))
}

/**
 * The Windows Phone text box (dark theme): a light grey box with black text, white while focused
 * with a border in the tile green. Under it, up to [maxSuggestions] earlier values that start with
 * what's typed, tap to fill (STR-04).
 */
@Composable
fun TextBox(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text,
    suggestions: List<String> = emptyList(),
    singleLine: Boolean = true,
    maxSuggestions: Int = 4,
) {
    val zpx = LocalZpx.current
    var focused by remember { mutableStateOf(false) }
    Column(modifier.fillMaxWidth().padding(bottom = zpx(12f))) {
        FieldLabel(label)
        BasicTextField(
            value = value,
            onValueChange = onChange,
            singleLine = singleLine,
            textStyle = textStyleFor(TennisTokens.Type.input).copy(color = Color.Black),
            cursorBrush = SolidColor(Color.Black),
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboard,
                capitalization = if (keyboard == KeyboardType.Text) KeyboardCapitalization.Sentences else KeyboardCapitalization.None,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused }
                .background(if (focused) Color.White else TennisTokens.Colors.textBox)
                .border(zpx(2f), if (focused) TennisTokens.Colors.tile else Color.Transparent)
                .padding(horizontal = zpx(8f), vertical = zpx(8f)),
        )
        if (focused) {
            val matches = suggestions.filter { it.isNotBlank() && it.startsWith(value.trim(), ignoreCase = true) && !it.equals(value.trim(), true) }
                .distinct().take(maxSuggestions)
            matches.forEach { s ->
                TennisText(s, TennisTokens.Type.listSecondary, Modifier.fillMaxWidth().press(description = s) { onChange(s) }.padding(vertical = zpx(6f)))
            }
        }
    }
}

/** The Windows Phone toggle switch: label, "On"/"Off", and a square-cornered switch. */
@Composable
fun ToggleSwitch(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    val zpx = LocalZpx.current
    Column(Modifier.fillMaxWidth().press(description = label, tilt = false) { onChange(!on) }.padding(bottom = zpx(12f))) {
        FieldLabel(label)
        Row(verticalAlignment = Alignment.CenterVertically) {
            TennisText(if (on) "On" else "Off", TennisTokens.Type.listPrimary, Modifier.weight(1f))
            Box(Modifier.size(zpx(46f), zpx(20f)).border(zpx(2f), TennisTokens.Colors.primary).padding(zpx(3f))) {
                if (on) Box(Modifier.size(zpx(28f), zpx(14f)).background(TennisTokens.Colors.tile))
                Box(Modifier.align(if (on) Alignment.CenterEnd else Alignment.CenterStart).size(zpx(10f), zpx(20f)).background(TennisTokens.Colors.primary))
            }
        }
    }
}

/**
 * A row of choices in the list size: the chosen one white, the others grey (Zune's category
 * style). [multi]: several can be chosen.
 */
@Composable
fun <T> ChoiceRow(label: String?, options: List<Pair<T, String>>, chosen: Set<T>, onPick: (T) -> Unit, wrap: Boolean = true) {
    val zpx = LocalZpx.current
    Column(Modifier.fillMaxWidth().padding(bottom = zpx(12f))) {
        if (label != null) FieldLabel(label)
        FlowRowSimple(gap = zpx(16f)) {
            options.forEach { (v, text) ->
                val style = textStyleFor(TennisTokens.Type.choice).let { if (v in chosen) it.copy(color = TennisTokens.Colors.primary) else it.copy(color = TennisTokens.Colors.disabled) }
                BasicText(text, style = style, modifier = Modifier.press(description = text) { onPick(v) }.padding(vertical = zpx(4f)))
            }
        }
    }
}

/** A minimal flow row: children left to right, wrapping, [gap] between them and between lines. */
@Composable
fun FlowRowSimple(gap: androidx.compose.ui.unit.Dp, content: @Composable () -> Unit) {
    androidx.compose.ui.layout.Layout(content) { measurables, constraints ->
        val g = gap.roundToPx()
        val ps = measurables.map { it.measure(constraints.copy(minWidth = 0)) }
        var x = 0; var y = 0; var lineH = 0
        val pos = ps.map { p ->
            if (x > 0 && x + p.width > constraints.maxWidth) { x = 0; y += lineH + g / 2; lineH = 0 }
            val at = x to y
            x += p.width + g; lineH = maxOf(lineH, p.height)
            at
        }
        layout(constraints.maxWidth, y + lineH) { ps.forEachIndexed { i, p -> p.place(pos[i].first, pos[i].second) } }
    }
}

/** A date with earlier / later / today actions (no Material date picker, NAV-07). */
@Composable
fun DateField(label: String, epochDay: Long, onChange: (Long) -> Unit, today: Long = java.time.LocalDate.now().toEpochDay()) {
    val zpx = LocalZpx.current
    Column(Modifier.fillMaxWidth().padding(bottom = zpx(12f))) {
        FieldLabel(label)
        TennisText(io.github.wotworth.tennis.domain.Strings.dayText(epochDay), TennisTokens.Type.listPrimary)
        Spacer(Modifier.height(zpx(4f)))
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(20f))) {
            SmallAction("earlier") { onChange(epochDay - 1) }
            SmallAction("later", enabled = epochDay < today) { onChange(epochDay + 1) }
            SmallAction("today", enabled = epochDay != today) { onChange(today) }
        }
    }
}

@Composable
fun SmallAction(label: String, enabled: Boolean = true, onClick: () -> Unit) {
    val style = textStyleFor(TennisTokens.Type.listSecondary)
    BasicText(
        label,
        style = style.copy(color = if (enabled) TennisTokens.Colors.primary else TennisTokens.Colors.disabled),
        modifier = (if (enabled) Modifier.press(description = label, onClick = onClick) else Modifier).padding(vertical = LocalZpx.current(4f)),
    )
}

@Composable
fun SectionHeader(text: String) {
    val zpx = LocalZpx.current
    Spacer(Modifier.height(zpx(10f)))
    TennisText(text, TennisTokens.Type.sectionHeader)
    Spacer(Modifier.height(zpx(8f)))
}

@Composable
fun Gap(z: Float) = Spacer(Modifier.height(LocalZpx.current(z)).width(LocalZpx.current(1f)))
