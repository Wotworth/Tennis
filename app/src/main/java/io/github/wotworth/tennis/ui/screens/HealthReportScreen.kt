package io.github.wotworth.tennis.ui.screens

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import androidx.health.connect.client.PermissionController
import io.github.wotworth.tennis.TennisApp
import io.github.wotworth.tennis.health.DayData
import io.github.wotworth.tennis.health.HealthReport
import io.github.wotworth.tennis.health.HealthSource
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate

/** What the report screen shows; plain values, so screenshot tests can supply them. */
data class HealthReportState(
    val availability: HealthSource.Availability = HealthSource.Availability.Available,
    val grantedCount: Int = 0,
    val neededCount: Int = HealthSource.permissions.size,
    val day: LocalDate = LocalDate.now(),
    val loading: Boolean = false,
    val data: DayData? = null,
    val error: String? = null,
) {
    val allGranted get() = grantedCount >= neededCount
}

/** DET-01: the Health Connect report for one day, read on the phone. */
@Composable
fun HealthReportScreen(app: TennisApp) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf(HealthReportState(availability = app.health.availability())) }

    fun load() {
        if (state.availability != HealthSource.Availability.Available) return
        scope.launch {
            state = state.copy(loading = true, error = null)
            state = try {
                val granted = app.health.granted().count { it in HealthSource.permissions }
                val data = if (granted > 0) app.health.read(state.day) else null
                state.copy(grantedCount = granted, data = data, loading = false)
            } catch (e: Exception) {
                state.copy(loading = false, error = e.message ?: e.javaClass.simpleName)
            }
        }
    }

    val ask = rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()) { load() }
    LaunchedEffect(state.day) { load() }

    HealthReportContent(
        state,
        onAllow = { ask.launch(HealthSource.permissions) },
        onDay = { d -> state = state.copy(day = d, data = null) },
        onShare = {
            val data = state.data ?: return@HealthReportContent
            scope.launch {
                val uri = withContext(Dispatchers.IO) {
                    val dir = File(context.cacheDir, "reports").apply { mkdirs() }
                    val file = File(dir, "health-connect-${data.day}.txt")
                    file.writeText(HealthReport.dump(data, "app: ${app.versionText}\nandroid: ${app.androidText}\naccess: ${state.grantedCount} of ${state.neededCount} permissions"))
                    FileProvider.getUriForFile(context, "io.github.wotworth.tennis.files", file)
                }
                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                context.startActivity(Intent.createChooser(send, null))
            }
        },
    )
}

@Composable
fun HealthReportContent(state: HealthReportState, onAllow: () -> Unit, onDay: (LocalDate) -> Unit, onShare: () -> Unit) {
    val zpx = LocalZpx.current
    val t = TennisTokens.Type
    Page("health") {
        when (state.availability) {
            HealthSource.Availability.Missing -> { TennisText("Health Connect isn't available on this phone.", t.listPrimary); return@Page }
            HealthSource.Availability.NeedsUpdate -> { TennisText("Health Connect needs an update from the Play Store first.", t.listPrimary); return@Page }
            HealthSource.Availability.Available -> Unit
        }
        if (!state.allGranted) {
            TextRow(
                "allow access",
                "Heart rate, steps, workouts, resting heart rate and past data: ${state.grantedCount} of ${state.neededCount} allowed",
                onClick = onAllow,
            )
        }
        // The day, with earlier and later.
        TennisText(HealthReport.dayTitle(state.day), t.listPrimary)
        Spacer(Modifier.height(zpx(6f)))
        io.github.wotworth.tennis.ui.components.FlowRowSimple(gap = zpx(18f)) {
            val earliest = LocalDate.now().minusDays(TennisTokens.Health.reportMaxDaysBack.toLong())
            DayAction("month earlier", state.day.minusDays(30) >= earliest) { onDay(state.day.minusDays(30)) }
            DayAction("week earlier", state.day.minusDays(7) >= earliest) { onDay(state.day.minusDays(7)) }
            DayAction("earlier day", state.day > earliest) { onDay(state.day.minusDays(1)) }
            DayAction("later day", state.day < LocalDate.now()) { onDay(state.day.plusDays(1)) }
        }
        Spacer(Modifier.height(zpx(18f)))
        when {
            state.error != null -> TennisText("Couldn't read Health Connect: ${state.error}", t.listSecondary)
            state.loading -> TennisText("reading…", t.listSecondary)
            state.grantedCount == 0 -> TennisText("Allow access to see this day's data.", t.listSecondary)
            state.data != null -> {
                for ((heading, lines) in HealthReport.summary(state.data)) {
                    TennisText(heading, t.listPrimary)
                    Spacer(Modifier.height(zpx(4f)))
                    lines.forEach { TennisText(it, t.listSecondary); Spacer(Modifier.height(zpx(3f))) }
                    Spacer(Modifier.height(zpx(12f)))
                }
                TextRow("share full report", "Every reading as a text file, to attach in a session", onClick = onShare)
            }
        }
    }
}

@Composable
private fun DayAction(label: String, enabled: Boolean, onClick: () -> Unit) {
    val style = io.github.wotworth.tennis.ui.theme.textStyleFor(TennisTokens.Type.listSecondary)
    androidx.compose.foundation.text.BasicText(
        label,
        style = if (enabled) style.copy(color = TennisTokens.Colors.primary) else style.copy(color = TennisTokens.Colors.disabled),
        modifier = if (enabled) Modifier.press(description = label, onClick = onClick) else Modifier,
    )
}
