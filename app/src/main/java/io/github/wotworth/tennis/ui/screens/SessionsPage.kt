package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.data.AppData
import io.github.wotworth.tennis.data.Proposal
import io.github.wotworth.tennis.data.SessionWithRacquets
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.Tile
import io.github.wotworth.tennis.ui.components.TileLines
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** NAV-03: sessions, newest first. */
@Composable
fun SessionsPage() {
    val data = appData()
    val zpx = LocalZpx.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    PivotColumn {
        ProposalTiles()
        if (data.loaded && data.sessions.isEmpty()) {
            TennisText("No sessions yet.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Tap + to log one. Sessions your Fitbit finds show up here for a yes or no.", TennisTokens.Type.listSecondary)
        }
        data.sessions.forEach { s ->
            TextRow(sessionTitle(s), sessionDetail(s, data), onLongClick = {
                o.menu(
                    "edit" to { nav.open(Screen.SessionEdit(s.session.id)) },
                    "delete" to { o.confirm("delete session?", sessionTitle(s), "delete") { scope.launch { app.repo.deleteSession(s.session.id) } } },
                )
            }) { nav.open(Screen.SessionEdit(s.session.id)) }
        }
    }
}

fun sessionTitle(s: SessionWithRacquets) = "${Strings.shortDayText(s.session.date, Now.day())} · ${Strings.minutesText(s.session.minutes)}"

fun sessionDetail(s: SessionWithRacquets, d: AppData, withRacquet: Boolean = true): String = buildList {
    if (withRacquet) add(s.racquetIds.mapNotNull { d.racquet(it)?.name }.firstOrNull() ?: "no racquet")
    s.session.feel?.let { add("feel $it") }
    s.session.avgHr?.let { add("$it avg bpm") }
    s.session.steps?.let { add("$it steps") }
}.joinToString(" · ")

private val clock = DateTimeFormatter.ofPattern("h:mm a", Locale.US)

/** "Today 5:10–6:35 PM", "Yesterday …", or "Tue 3 Nov …" (DET-30). */
fun windowText(p: Proposal, zone: ZoneId = ZoneId.systemDefault()): String {
    val s = Instant.ofEpochMilli(p.startMillis).atZone(zone)
    val e = Instant.ofEpochMilli(p.endMillis).atZone(zone)
    val day = s.toLocalDate().toEpochDay()
    val today = Now.day()
    val d = when (day) { today -> "Today"; today - 1 -> "Yesterday"; else -> Strings.shortDayText(day, today) }
    val st = clock.format(s).let { if (it.takeLast(2) == clock.format(e).takeLast(2)) it.dropLast(3) else it }
    return "$d $st–${clock.format(e)}"
}

/** DET-30: a wide tile per waiting proposal, oldest first, above the page's own content. */
@Composable
fun ProposalTiles() {
    val data = appData()
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val waiting = data.waiting
    if (waiting.isEmpty()) return
    waiting.forEach { p ->
        Tile("did you play tennis?", zpx(TennisTokens.Layout.tileMedium * 2 + TennisTokens.Layout.tileGap), zpx(TennisTokens.Layout.tileMedium * 0.75f), description = "did you play tennis? ${windowText(p)}", onClick = { nav.open(Screen.Proposal(p.id)) }) {
            TileLines(listOf(windowText(p), listOfNotNull(Strings.minutesText(((p.endMillis - p.startMillis) / 60000).toInt()), p.avgHr?.let { "$it avg bpm" }).joinToString(" · ")))
        }
        Spacer(Modifier.height(zpx(TennisTokens.Layout.tileGap)))
    }
    Spacer(Modifier.height(zpx(8f)))
}
