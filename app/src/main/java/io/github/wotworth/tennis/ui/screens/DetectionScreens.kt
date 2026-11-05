package io.github.wotworth.tennis.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.health.connect.client.PermissionController
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.domain.Detection
import io.github.wotworth.tennis.domain.DetectionSettings
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.domain.Strings
import io.github.wotworth.tennis.health.DayData
import io.github.wotworth.tennis.health.DetectionPrefs
import io.github.wotworth.tennis.health.DetectionRunner
import io.github.wotworth.tennis.health.HealthSource
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.components.FieldLabel
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.ToggleSwitch
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val hm = DateTimeFormatter.ofPattern("h:mm a", Locale.US)
private fun time(ms: Long, zone: ZoneId = ZoneId.systemDefault()) = hm.format(Instant.ofEpochMilli(ms).atZone(zone))

/** DET-02, DET-11, DET-20: the settings section for session detection. */
@Composable
fun DetectionSettingsSection() {
    val app = LocalApp.current
    val data = appData()
    val scope = rememberCoroutineScope()
    var s by remember { mutableStateOf(DetectionPrefs.load(app.prefs)) }
    var status by remember { mutableStateOf<String?>(null) }
    var birth by remember { mutableStateOf(s.birthYear.toString()) }
    fun save(n: DetectionSettings) { s = n; DetectionPrefs.save(app.prefs, n); runCatching { DetectionRunner.schedule(app, n) } }
    val ask = rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()) {
        scope.launch { status = runCatching { DetectionRunner.run(app).let { r -> if (r.ran) "checked: ${r.newCount} new" else r.message } }.getOrElse { it.message } }
    }
    SectionHeader("detected sessions")
    ToggleSwitch("find sessions in Health Connect", s.enabled) { save(s.copy(enabled = it)) }
    TextBox("birth year (sets your maximum heart rate)", birth, { v -> birth = v; v.toIntOrNull()?.takeIf { it in 1920..2020 }?.let { save(s.copy(birthYear = it)) } }, keyboard = KeyboardType.Number)
    val last = app.prefs.getLong("det.lastRun", 0L)
    TextRow(
        "check now",
        status ?: listOf(if (last == 0L) "not checked yet" else "last checked ${Strings.shortDayText(Instant.ofEpochMilli(last).atZone(ZoneId.systemDefault()).toLocalDate().toEpochDay(), Now.day())} ${time(last)}",
            "${data.waiting.size} waiting").joinToString(" · "),
    ) { ask.launch(HealthSource.permissions) }
}

/**
 * DET-11 (Chris, 5 Nov): the hidden debug screen (long-press the version in settings). Every
 * threshold, saved at once; and "try a day", which runs detection on any past day without saving.
 */
@Composable
fun DetectionDebugScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    var s by remember { mutableStateOf(DetectionPrefs.load(app.prefs)) }
    var text by remember { mutableStateOf(mapOf<String, String>()) }
    var day by remember { mutableStateOf(Now.day() - 1) }
    var result by remember { mutableStateOf<List<String>>(emptyList()) }
    fun set(n: DetectionSettings?) { if (n != null) { s = n; DetectionPrefs.save(app.prefs, n); runCatching { DetectionRunner.schedule(app, n) } } }
    @Composable fun num(label: String, key: String, now: String, parse: (String) -> DetectionSettings?) {
        val shown = text[key] ?: now
        TextBox(label, shown, { v -> text = text + (key to v); set(parse(v)) }, keyboard = KeyboardType.Decimal)
    }
    Page("debug", bar = listOf(BarButton(R.drawable.fluent_dismiss, "close") { nav.back() })) {
        TennisText("Detection settings. Changes are saved as you type and used from the next check.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(12f)))
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
            Column(Modifier.weight(1f)) { num("shortest session (min)", "min", s.minMinutes.toString()) { v -> v.toIntOrNull()?.takeIf { it in 5..240 }?.let { s.copy(minMinutes = it) } } }
            Column(Modifier.weight(1f)) { num("smoothing (min)", "roll", s.rollingMinutes.toString()) { v -> v.toIntOrNull()?.takeIf { it in 1..30 }?.let { s.copy(rollingMinutes = it) } } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
            Column(Modifier.weight(1f)) { num("longest break (min)", "gap", s.maxGapMinutes.toString()) { v -> v.toIntOrNull()?.takeIf { it in 0..30 }?.let { s.copy(maxGapMinutes = it) } } }
            Column(Modifier.weight(1f)) { num("reserve share (%)", "share", (s.reserveShare * 100).toInt().toString()) { v -> v.toIntOrNull()?.takeIf { it in 10..95 }?.let { s.copy(reserveShare = it / 100.0) } } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
            Column(Modifier.weight(1f)) { num("resting bpm if none", "rest", s.restingFallback.toString()) { v -> v.toIntOrNull()?.takeIf { it in 35..110 }?.let { s.copy(restingFallback = it) } } }
            Column(Modifier.weight(1f)) { num("birth year", "birth", s.birthYear.toString()) { v -> v.toIntOrNull()?.takeIf { it in 1920..2020 }?.let { s.copy(birthYear = it) } } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
            Column(Modifier.weight(1f)) { num("look back (hours)", "back", s.lookbackHours.toString()) { v -> v.toIntOrNull()?.takeIf { it in 6..168 }?.let { s.copy(lookbackHours = it) } } }
            Column(Modifier.weight(1f)) { num("check every (min)", "every", s.checkEveryMinutes.toString()) { v -> v.toIntOrNull()?.takeIf { it in 15..720 }?.let { s.copy(checkEveryMinutes = it) } } }
        }
        num("unanswered expire after (days)", "exp", s.expiryDays.toString()) { v -> v.toIntOrNull()?.takeIf { it in 1..60 }?.let { s.copy(expiryDays = it) } }
        ToggleSwitch("count squash, badminton and other racquet workouts", s.otherRacquetSports) { set(s.copy(otherRacquetSports = it)) }
        TextRow("reset to defaults", "Shortest 30 min, smoothing 5, break 5, share 50%") { text = emptyMap(); set(DetectionSettings(birthYear = s.birthYear, enabled = s.enabled)) }

        SectionHeader("try a day")
        TennisText(io.github.wotworth.tennis.domain.Strings.dayText(day), TennisTokens.Type.listPrimary)
        Spacer(Modifier.height(zpx(4f)))
        Row(horizontalArrangement = Arrangement.spacedBy(zpx(18f))) {
            SmallAction("month earlier") { day -= 30 }
            SmallAction("week earlier") { day -= 7 }
            SmallAction("earlier") { day -= 1 }
            SmallAction("later", enabled = day < Now.day()) { day += 1 }
        }
        Spacer(Modifier.height(zpx(8f)))
        TextRow("run on this day", "Shows what detection finds with these settings. Saves nothing.") {
            scope.launch {
                result = runCatching {
                    val d = app.health.read(LocalDate.ofEpochDay(day))
                    describe(d, s, LocalDate.ofEpochDay(day).year)
                }.getOrElse { listOf("Couldn't read Health Connect: ${it.message}") }
            }
        }
        result.forEach { TennisText(it, TennisTokens.Type.listSecondary); Spacer(Modifier.height(zpx(3f))) }
    }
}

/** The debug screen's plain-text result for one day. */
fun describe(d: DayData, s: DetectionSettings, year: Int, zone: ZoneId = d.zone): List<String> {
    val rest = Detection.resting(d, s)
    val th = Detection.threshold(s, rest, year)
    val found = Detection.detect(d, s, year)
    val longest = Detection.longestHot(d, s, th)
    val samples = d.heartRate.sumOf { it.samples.size }
    return buildList {
        add("$samples heart-rate readings; resting $rest bpm; max ${Detection.maxHr(s, year)}; threshold $th bpm")
        add(if (longest == null) "never at or above the threshold" else "longest stretch at or above it: ${longest.first} min from ${time(longest.second, zone)}")
        if (found.isEmpty()) add("no sessions found")
        found.forEach { c ->
            add("found: ${time(c.startMillis, zone)} to ${time(c.endMillis, zone)} (${Strings.minutesText(c.minutes)}), ${if (c.source == "workout") "Fitbit workout" else "heart rate"}" +
                listOfNotNull(c.avgHr?.let { ", avg $it" }, c.maxHr?.let { ", max $it" }, c.peakRolling?.let { ", peak smoothed $it" }, c.steps?.let { ", $it steps" }).joinToString(""))
        }
        d.exercise.forEach { add("workout in Health Connect: ${it.typeName} ${time(it.start.toEpochMilli(), zone)} to ${time(it.end.toEpochMilli(), zone)}") }
    }
}
