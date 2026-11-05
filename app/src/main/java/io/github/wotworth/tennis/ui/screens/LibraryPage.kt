package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import io.github.wotworth.tennis.data.Repository
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch

/** NAV-05: all string jobs (every racquet), then the string library (STR-30). */
@Composable
fun LibraryPage() {
    val d = appData()
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    val zpx = LocalZpx.current
    PivotColumn {
        if (d.loaded && d.jobs.isEmpty() && d.strings.isEmpty()) {
            TennisText("Nothing here yet.", TennisTokens.Type.listPrimary)
            Spacer(Modifier.height(zpx(6f)))
            TennisText("Restrings you log, and the strings in them, are listed here.", TennisTokens.Type.listSecondary)
            return@PivotColumn
        }
        if (d.jobs.isNotEmpty()) {
            SectionHeader("restrings")
            d.jobs.forEach { j ->
                val r = d.racquet(j.racquetId)
                val hours = Strings.hoursText(Strings.hours(j, d.jobs, d.sessions))
                TextRow(
                    "${Strings.shortDayText(j.date, Now.day())} · ${r?.name ?: ""}",
                    listOf("${Strings.setupText(j)} @ ${Strings.tensionText(j)} lb", j.shop, Strings.money(j.priceCents), "$hours h").filter { it.isNotBlank() }.joinToString(" · "),
                    onLongClick = { o.menu("shop order" to { nav.open(Screen.ShopOrder(j.id)) }, "edit" to { nav.open(Screen.RestringEdit(j.racquetId, j.id)) }) },
                ) { nav.open(Screen.RestringEdit(j.racquetId, j.id)) }
            }
        }
        if (d.strings.isNotEmpty()) {
            SectionHeader("strings")
            d.strings.forEach { st ->
                val used = d.jobs.filter { Repository.same(it.mains, st.spec) || (it.hybrid && Repository.same(it.crossesOwn, st.spec)) }
                val feels = used.flatMap { Strings.feels(it, d.jobs, d.sessions) }
                TextRow(
                    listOf(st.spec.name, st.spec.gauge).filter { it.isNotBlank() }.joinToString(" "),
                    listOf(st.spec.material, if (used.size == 1) "used once" else "used ${used.size} times", if (feels.isEmpty()) "" else "feel %.1f".format(java.util.Locale.US, feels.average()))
                        .filter { it.isNotBlank() }.joinToString(" · "),
                    onLongClick = { o.menu("edit" to { nav.open(Screen.StringEdit(st.id)) }, "delete" to { o.confirm("delete string?", st.spec.name, "delete") { scope.launch { app.repo.deleteString(st) } } }) },
                ) { nav.open(Screen.StringEdit(st.id)) }
            }
        }
    }
}
