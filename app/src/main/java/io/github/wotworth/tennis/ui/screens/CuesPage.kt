package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.data.Cue
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch

/**
 * CUE-10 (v0.2): the cues page is the warmup view. Pinned cues first, large, in pinned order;
 * the rest below in the list size. Long-press a cue for pin, move and delete (CUE-02).
 */
@Composable
fun CuesPage() {
    val data = appData()
    val zpx = LocalZpx.current
    PivotColumn {
        ProposalTiles()
        val pinned = data.cues.filter { it.pinned }
        val others = data.cues.filter { !it.pinned }
        if (data.cues.isEmpty() && data.loaded) {
            TennisText("Add your swing cues with +.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Pin the ones you want to read before you play: they show here in large type.", TennisTokens.Type.listSecondary)
        }
        // CUE-10, CUE-03 (v0.5): grouped by stroke, the stroke's name once in its colour with a
        // colour bar beside its cues; pinned first (in pinned order), the rest below, smaller.
        CueGroups(pinned, data.cues, TennisTokens.Type.warmupCue)
        if (others.isNotEmpty()) {
            if (pinned.isNotEmpty()) SectionHeader("other cues")
            CueGroups(others, data.cues, TennisTokens.Type.cueOther)
        }
    }
}

@Composable
private fun cueMenu(c: Cue, all: List<Cue>): () -> Unit {
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val scope = rememberCoroutineScope()
    return {
        val i = all.indexOfFirst { it.id == c.id }
        fun move(d: Int) = scope.launch {
            val list = all.toMutableList(); val j = i + d
            if (j in list.indices) { list.add(j, list.removeAt(i)); app.repo.reorderCues(list) }
        }
        val items = buildList<Pair<String, () -> Unit>> {
            add((if (c.pinned) "unpin from warmup" else "pin to warmup") to { scope.launch { app.repo.saveCue(c.copy(pinned = !c.pinned)) }; Unit })
            add("edit" to { nav.open(Screen.CueEdit(c.id)) })
            if (i > 0) add("move up" to { move(-1); Unit })
            if (i < all.lastIndex) add("move down" to { move(1); Unit })
            add("delete" to { o.confirm("delete cue?", c.text, "delete") { scope.launch { app.repo.deleteCue(c) } } })
        }
        o.menu(*items.toTypedArray())
    }
}

/** Cues grouped by stroke, in order of each stroke's first cue (CUE-03). */
@Composable
private fun CueGroups(cues: List<Cue>, all: List<Cue>, role: TennisTokens.Role) {
    val zpx = LocalZpx.current
    val c = TennisTokens.Cues
    cues.groupBy { it.heading.trim().lowercase() }.forEach { (heading, group) ->
        val colour = TennisTokens.Colors.stroke(heading)
        androidx.compose.foundation.layout.Row(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.IntrinsicSize.Min).padding(bottom = zpx(c.betweenStrokes))) {
            androidx.compose.foundation.layout.Box(Modifier.width(zpx(c.barWidth)).fillMaxHeight().background(colour))
            androidx.compose.foundation.layout.Column(Modifier.padding(start = zpx(c.barGap))) {
                androidx.compose.foundation.text.BasicText(heading.ifBlank { "other" }, style = io.github.wotworth.tennis.ui.theme.textStyleFor(TennisTokens.Type.cueHeading).copy(color = colour))
                Spacer(Modifier.height(zpx(5f)))
                group.forEachIndexed { i, cue ->
                    val menu = cueMenu(cue, all)
                    TennisText(cue.text, role, Modifier.fillMaxWidth().press(onLongClick = menu, description = cue.text, onClick = menu))
                    if (i < group.lastIndex) Spacer(Modifier.height(zpx(c.betweenCues)))
                }
            }
        }
    }
}
