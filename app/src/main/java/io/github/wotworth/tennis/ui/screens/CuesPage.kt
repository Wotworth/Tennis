package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
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
        pinned.forEach { c ->
            val menu = cueMenu(c, data.cues)
            androidx.compose.foundation.layout.Column(Modifier.fillMaxWidth().press(onLongClick = menu, description = c.text, onClick = menu).padding(bottom = zpx(16f))) {
                TennisText(c.heading, TennisTokens.Type.listSecondary)
                Spacer(Modifier.height(zpx(3f)))
                TennisText(c.text, TennisTokens.Type.warmupCue)
            }
        }
        if (others.isNotEmpty()) {
            if (pinned.isNotEmpty()) SectionHeader("other cues")
            others.forEach { c -> TextRow(c.text, c.heading, onLongClick = cueMenu(c, data.cues), onClick = cueMenu(c, data.cues)) }
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
