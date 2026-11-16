package io.github.wotworth.tennis.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.LocalNav
import io.github.wotworth.tennis.ui.Screen
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.LocalOverlays
import io.github.wotworth.tennis.ui.components.MetroButton
import io.github.wotworth.tennis.ui.components.Page
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import io.github.wotworth.tennis.vision.CheckAnswer
import io.github.wotworth.tennis.vision.Feedback
import io.github.wotworth.tennis.vision.VisionStore
import kotlin.math.roundToInt

/**
 * "Ball check" (Chris, 15 Nov): one crop at a time from the PC's picks, the detector's marker on
 * it. Tap "on the ball", tap where the ball really is, or "no ball". Builds the hand-labelled
 * test set the retrained detector is judged on. Fits a phone or a tablet (the crop is at most
 * 480 dp square).
 */
@Composable
fun BallCheckScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val checks = app.vision.checks(app.prefs.visionSample)
    val total = remember { checks.size }
    Page("ball check") {
        val c = checks.firstOrNull()
        if (c == null) {
            TennisText("All checked. Thanks: these frames judge every new detector before it is used.", TennisTokens.Type.body)
            Spacer(Modifier.height(zpx(12f)))
            MetroButton("done") { nav.back() }
            return@Page
        }
        TennisText("${total - checks.size + 1} of $total · is the ring on the ball? If not, tap the ball.", TennisTokens.Type.listSecondary)
        Spacer(Modifier.height(zpx(8f)))
        val b = remember(c.id) { app.vision.checkImage(c) }
        Box(Modifier.fillMaxWidth().widthIn(max = 480.dp).aspectRatio(1f).pointerInput(c.id) {
            detectTapGestures { p ->
                val s = 256f / size.width
                app.vision.answer(c, CheckAnswer.Moved((p.x * s).toDouble(), (p.y * s).toDouble()))
            }
        }) {
            if (b != null) Image(b.asImageBitmap(), "frame to check", contentScale = ContentScale.FillBounds, modifier = Modifier.fillMaxSize())
            Canvas(Modifier.fillMaxSize()) {
                val k = size.width / 256f
                drawCircle(TennisTokens.Colors.primary, 9f * k, Offset((c.predX * k).toFloat(), (c.predY * k).toFloat()), style = Stroke(1.6f * density))
            }
        }
        Spacer(Modifier.height(zpx(12f)))
        Row {
            MetroButton("✓ on the ball") { app.vision.answer(c, CheckAnswer.Ok) }
            Spacer(Modifier.width(zpx(10f)))
            MetroButton("no ball") { app.vision.answer(c, CheckAnswer.NoBall) }
        }
        Spacer(Modifier.height(zpx(10f)))
        SmallAction("stop for now") { nav.back() }
        if (app.prefs.visionSample) {
            Spacer(Modifier.height(zpx(10f)))
            TennisText("Sample crops (synthetic). Answers wait on the phone until the cloud is set up.", TennisTokens.Type.listSecondary)
        }
    }
}

/**
 * "Who did you play?" (Chris, 15 Nov): after a session is processed, one tap. Saved opponents,
 * most recently played first; the opponent from the last session at the same court is
 * suggested (marked), never chosen for him; "add new"; "skip / unknown".
 */
@Composable
fun OpponentPromptScreen(sessionId: String) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val d = appData()
    val opp = app.vision.opponents
    @Suppress("UNUSED_VARIABLE") val v = opp.version
    var adding by remember { mutableStateOf("") }
    val sessions = app.vision.sessions(app.prefs.visionSample)
    val history = sessions.filter { it.id != sessionId }.map { s -> Triple(s.startUtc, d.visionLabel(s.id)?.courtId, opp.of(s.id)?.id) }
    val suggested = Feedback.suggest(d.visionLabel(sessionId)?.courtId, history)
    fun choose(id: Int?) { opp.choose(sessionId, id); app.vision.outbox.add("/sessions/$sessionId/opponent", Feedback.opponent(id)); nav.back() }
    Page("who did you play?") {
        val list = opp.all { id -> sessions.filter { opp.of(it.id)?.id == id }.maxOfOrNull { it.startUtc } }
        list.forEach { o -> TextRow(o.name, if (o.id == suggested) "last time at this court" else null) { choose(o.id) } }
        SectionHeader("add new")
        TextBox("name", adding, { adding = it })
        SmallAction("add and choose", adding.isNotBlank()) { choose(opp.add(adding).id) }
        Spacer(Modifier.height(zpx(14f)))
        TextRow("skip / unknown", "the session keeps \"Player B\"") { choose(null) }
        Spacer(Modifier.height(zpx(8f)))
        TennisText("Names are kept in your cloud database only, never on the PC or in the code.", TennisTokens.Type.listSecondary)
    }
}

/** The saved opponents: open, rename, merge a duplicate into another, delete. */
@Composable
fun OpponentsScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val o = LocalOverlays.current
    val opp = app.vision.opponents
    @Suppress("UNUSED_VARIABLE") val v = opp.version
    val sessions = app.vision.sessions(app.prefs.visionSample)
    Page("opponents") {
        val list = opp.all { id -> sessions.filter { opp.of(it.id)?.id == id }.maxOfOrNull { it.startUtc } }
        if (list.isEmpty()) TennisText("No opponents yet. Pick one after a session (\"who did you play?\").", TennisTokens.Type.body)
        list.forEach { p ->
            TextRow(p.name, "${opp.sessionsOf(p.id).size} session${if (opp.sessionsOf(p.id).size == 1) "" else "s"}", onLongClick = {
                o.menu(*buildList<Pair<String, () -> Unit>> {
                    list.filter { it.id != p.id }.forEach { q -> add("merge into ${q.name}" to { opp.merge(p.id, q.id) }) }
                    add("delete" to { o.confirm("delete ${p.name}?", "Their sessions keep \"Player B\".", "delete") { opp.delete(p.id) } })
                }.toTypedArray())
            }) { nav.open(Screen.Opponent(p.id)) }
        }
    }
}

/** One opponent: rename, their sessions with your headline next to theirs, their stats (only from sessions where you turned them on). */
@Composable
fun OpponentScreen(id: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val opp = app.vision.opponents
    @Suppress("UNUSED_VARIABLE") val v = opp.version
    val p = opp.byId(id) ?: run { Page("opponent") { TennisText("This opponent was deleted.", TennisTokens.Type.body) }; return }
    var name by remember(id) { mutableStateOf(p.name) }
    Page(p.name) {
        TextBox("name", name, { name = it })
        SmallAction("rename", name.isNotBlank() && name != p.name) { opp.rename(id, name) }
        SectionHeader("head to head")
        val sessions = app.vision.sessions(app.prefs.visionSample).filter { opp.of(it.id)?.id == id }
        if (sessions.isEmpty()) TennisText("No sessions yet.", TennisTokens.Type.listSecondary)
        sessions.forEach { s ->
            val answer = if (s.sample) app.prefs.visionSampleIdentity else null
            val mine = s.shots.filter { s.who(it.hitter, answer) == "you" }
            val theirs = s.shots.filter { s.who(it.hitter, answer) != "you" }
            TextRow(visionDay(s), "you: ${playerLine(mine)}") { nav.open(Screen.Vision(s.id)) }
            if (s.id in app.prefs.opponentStatsOn) TextRow("${p.name}: ${playerLine(theirs)}", null)
        }
        Spacer(Modifier.height(zpx(8f)))
        TennisText("Their figures show only for sessions where \"opponent's stats\" is on.", TennisTokens.Type.listSecondary)
    }
}

/** "Missed a shot here": pick the moment in the rally; the PC looks again around it. */
@Composable
fun MissedShotScreen(sessionId: String, rally: Int) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val zpx = LocalZpx.current
    val v = app.vision.session(sessionId) ?: return
    val r = v.rallies.firstOrNull { it.index == rally } ?: return
    var f by remember { mutableStateOf(0.5f) }
    Page("missed a shot?") {
        app.vision.rallyFrame(sessionId, rally)?.let { b ->
            Image(b.asImageBitmap(), "rally $rally", contentScale = ContentScale.FillWidth, modifier = Modifier.fillMaxWidth())
        }
        Spacer(Modifier.height(zpx(10f)))
        val t = r.start + f * (r.stop - r.start)
        TennisText("rally $rally at %.1f s of %.0f: drag to where the shot was".format(java.util.Locale.US, t - r.start, r.stop - r.start), TennisTokens.Type.body)
        Canvas(Modifier.fillMaxWidth().height(zpx(TennisTokens.Vision.scrubberHeight)).pointerInput(Unit) {
            detectDragGestures { c: androidx.compose.ui.input.pointer.PointerInputChange, _: Offset -> f = (c.position.x / size.width).coerceIn(0f, 1f) }
        }.pointerInput(Unit) { detectTapGestures { pp -> f = (pp.x / size.width).coerceIn(0f, 1f) } }) {
            val y = size.height / 2
            drawLine(TennisTokens.Colors.disabled, Offset(0f, y), Offset(size.width, y), strokeWidth = 2f * density)
            drawRect(TennisTokens.Colors.primary, Offset(size.width * f - 4 * density, y - 10 * density), androidx.compose.ui.geometry.Size(8 * density, 20 * density))
        }
        Spacer(Modifier.height(zpx(12f)))
        MetroButton("missed a shot here") { app.vision.flag(sessionId, Feedback.missedShot(rally, (t * 10).roundToInt() / 10.0)); nav.back() }
    }
}
