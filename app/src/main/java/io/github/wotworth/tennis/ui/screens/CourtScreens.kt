package io.github.wotworth.tennis.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import io.github.wotworth.tennis.R
import io.github.wotworth.tennis.data.Court
import io.github.wotworth.tennis.data.VisionLabel
import io.github.wotworth.tennis.photos.Photos
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.BarButton
import io.github.wotworth.tennis.ui.components.ChoiceRow
import io.github.wotworth.tennis.ui.components.FieldLabel
import io.github.wotworth.tennis.ui.components.FlowRowSimple
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.MetroButton
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.components.ToggleSwitch
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.CourtPick
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Tennis Vision courts (Chris, 15 Nov), all on the phone: no location permission, and names and
 * photos never leave it. A court is how the cameras were set up there, so next time it is just
 * a matter of picking it.
 */
val LAYOUTS = listOf(1 to "one side, level with each baseline", 2 to "back-fence corners, one side")
val LENS_MODES = listOf("16:9" to "16:9", "4:3 open gate" to "4:3 open gate")

fun layoutText(layout: Int) = LAYOUTS.firstOrNull { it.first == layout }?.second ?: "layout $layout"

fun courtLine(c: Court) = listOf("layout ${c.layout}", c.lensMode, if (c.indoor) "indoor" else "outdoor").joinToString(" · ")

private val pickClock = DateTimeFormatter.ofPattern("EEE h:mm a", Locale.US)

@Composable
fun CourtScreen(id: Long) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    val c = d.court(id) ?: run { Page("court") { TennisText("This court was deleted.", TennisTokens.Type.listPrimary) }; return }
    Page(c.name, bar = listOf(
        BarButton(R.drawable.fluent_edit, "edit") { nav.open(Screen.CourtEdit(c.id)) },
        BarButton(R.drawable.fluent_delete, "delete") {
            o.confirm("delete ${c.name}?", "Sessions labelled with it keep their recordings, without the name.", "delete") {
                scope.launch { if (app.prefs.courtPickId == c.id) app.prefs.pickCourt(null); app.repo.deleteCourt(c); nav.back() }
            }
        },
    )) {
        TextRow("layout ${c.layout}", layoutText(c.layout))
        TextRow(c.lensMode, "lens mode that worked here")
        TextRow(if (c.indoor) "indoor" else "outdoor", if (c.indoor) "wind is taken as zero; indoor temperature and humidity" else "weather from the forecast")
        photoBitmap(c.photo, 1080)?.let { b ->
            FieldLabel("camera mounts")
            Image(b.asImageBitmap(), "camera mounts at ${c.name}", contentScale = ContentScale.FillWidth, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(zpx(12f)))
        }
        Spacer(Modifier.height(zpx(8f)))
        if (app.prefs.courtPickId == c.id) {
            val at = pickClock.format(Instant.ofEpochMilli(app.prefs.courtPickMillis).atZone(ZoneId.systemDefault())).lowercase()
            TennisText("Picked $at. The next vision session gets this court's name.", TennisTokens.Type.body)
            Spacer(Modifier.height(zpx(8f)))
            MetroButton("unpick") { app.prefs.pickCourt(null) }
        } else {
            MetroButton("playing here now") { app.prefs.pickCourt(c.id) }
        }
    }
}

@Composable
fun CourtEditScreen(id: Long?) {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val ctx = LocalContext.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    val old = id?.let { d.court(it) }
    var name by remember(old) { mutableStateOf(old?.name ?: "") }
    var layout by remember(old) { mutableStateOf(old?.layout ?: 1) }
    var lens by remember(old) { mutableStateOf(old?.lensMode ?: "16:9") }
    var indoor by remember(old) { mutableStateOf(old?.indoor ?: false) }
    var photo by remember(old) { mutableStateOf(old?.photo) }
    var pending by remember { mutableStateOf<String?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val n = pending ?: return@rememberLauncherForActivityResult
        if (ok) photo = n else Photos.file(ctx, n).delete()
        pending = null
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch { photo = Photos.importPicked(ctx, uri) }
    }
    Page(if (old == null) "new court" else "court", bar = listOf(
        BarButton(R.drawable.fluent_checkmark, "save", name.isNotBlank()) {
            scope.launch {
                app.repo.saveCourt((old ?: Court(name = name.trim())).copy(name = name.trim(), layout = layout, lensMode = lens, indoor = indoor, photo = photo))
                nav.back()
            }
        },
        BarButton(R.drawable.fluent_dismiss, "cancel") { nav.back() },
    )) {
        TextBox("name", name, { name = it })
        ChoiceRow("camera layout", LAYOUTS, setOf(layout), { layout = it })
        ChoiceRow("lens mode that worked", LENS_MODES, setOf(lens), { lens = it })
        ToggleSwitch("indoor", indoor) { indoor = it }
        FieldLabel("photo of the camera mounts (optional)")
        photoBitmap(photo, 360)?.let { b ->
            Image(b.asImageBitmap(), "camera mounts", contentScale = ContentScale.FillWidth, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(zpx(8f)))
        }
        FlowRowSimple(gap = zpx(16f)) {
            SmallAction(if (photo == null) "take photo" else "retake") { val (n, uri) = Photos.newCapture(ctx); pending = n; camera.launch(uri) }
            SmallAction("choose photo") { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            if (photo != null) SmallAction("remove photo") { photo = null }
        }
        Spacer(Modifier.height(zpx(8f)))
        TennisText("The name and photo stay on this phone.", TennisTokens.Type.listSecondary)
    }
}

/** On the sessions page: the court picked for the next session, and labelling that session. */
@Composable
fun CourtPickRow() {
    val d = appData()
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    val pickId = app.prefs.courtPickId
    val sessions = app.vision.sessions(app.prefs.visionSample)
    LaunchedEffect(pickId, sessions, d.visionLabels) {
        val c = d.court(pickId) ?: return@LaunchedEffect
        val spans = sessions.mapNotNull { CourtPick.span(it) }
        val id = CourtPick.match(spans, app.prefs.courtPickMillis, d.visionLabels.map { it.sessionId }.toSet(),
            TennisTokens.Vision.courtPickHours) ?: return@LaunchedEffect
        scope.launch {
            app.repo.labelVisionSession(VisionLabel(id, c.id, indoor = c.indoor))
            app.prefs.pickCourt(null)
        }
    }
    val c = d.court(pickId) ?: return
    TextRow("playing at ${c.name}", "the next vision session gets this court") { nav.open(Screen.Court(c.id)) }
    Spacer(Modifier.height(zpx(8f)))
}
