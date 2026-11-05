package io.github.wotworth.tennis.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import io.github.wotworth.tennis.data.Backup
import io.github.wotworth.tennis.domain.Now
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.press
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Extra settings rows added by later phases (detection, the API key). */
object SettingsExtras { val sections = mutableListOf<@Composable () -> Unit>() }

/** NAV-08: settings. Long-press the version line for the debug screen (PH-2). */
@Composable
fun SettingsScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val r = runCatching { withContext(Dispatchers.IO) { ctx.contentResolver.openOutputStream(uri)!!.use { Backup.write(app.repo.snapshot(), app.photosDir, it) } } }
            o.tell(if (r.isSuccess) "exported" else "couldn't export", r.exceptionOrNull()?.message ?: "Keep the file somewhere safe, like Google Drive.")
        }
    }
    val import = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        o.confirm("replace everything?", "Importing replaces all racquets, restrings, sessions, cues and strings on this phone with the ones in the file.", "import") {
            scope.launch {
                val r = runCatching {
                    val b = withContext(Dispatchers.IO) { ctx.contentResolver.openInputStream(uri)!!.use { Backup.read(it, app.photosDir) } }
                    app.repo.replaceAll(b)
                }
                o.tell(if (r.isSuccess) "imported" else "couldn't import", r.exceptionOrNull()?.message ?: "Everything from the file is back.")
            }
        }
    }
    Page("settings") {
        SectionHeader("racquet strings page")
        ChoiceRow("tile layout (pick the one you like)", listOf(1 to "grid", 2 to "hero", 3 to "mixed"), setOf(app.prefs.stringsLayout), { app.prefs.chooseStringsLayout(it) })
        SectionHeader("launcher tile")
        ChoiceRow("the WP launcher's tennis tile shows", listOf(false to "the last-used racquet", true to "each racquet in turn"), setOf(app.prefs.tileFlips), {
            app.prefs.chooseTileFlips(it); app.onDataChanged()
        })
        DetectionSettingsSection()
        ApiKeySection()
        SettingsExtras.sections.forEach { it() }
        SectionHeader("backup")
        TextRow("export", "Save everything, with photos, to a file") {
            export.launch("tennis-backup-${java.time.LocalDate.ofEpochDay(Now.day())}.zip")
        }
        TextRow("import", "Replace everything with a backup file") { import.launch(arrayOf("application/zip", "application/octet-stream")) }
        SectionHeader("diagnostics")
        TextRow("health connect report", "What your Fitbit data in Health Connect looks like, for one day") { nav.open(Screen.HealthReport) }
        TextRow("crash log", "Errors the app recorded, to paste into a session") { nav.open(Screen.CrashLog) }
        Spacer(Modifier.height(LocalZpx.current(12f)))
        TennisText("version ${app.versionText}", TennisTokens.Type.listSecondary, Modifier.press(onLongClick = { nav.open(Screen.Debug) }, tilt = false) {})
    }
}

/** DET-11: the hidden tuning screen. */
@Composable
fun DebugScreen() {
    DetectionDebugScreen()
}

