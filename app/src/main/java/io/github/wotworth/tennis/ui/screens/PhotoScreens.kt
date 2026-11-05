package io.github.wotworth.tennis.ui.screens

import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import io.github.wotworth.tennis.data.StringJob
import io.github.wotworth.tennis.data.StringSpec
import io.github.wotworth.tennis.photos.ApiKeyStore
import io.github.wotworth.tennis.photos.ClaudeReader
import io.github.wotworth.tennis.photos.PackageText
import io.github.wotworth.tennis.photos.Photos
import io.github.wotworth.tennis.ui.LocalApp
import io.github.wotworth.tennis.ui.appData
import io.github.wotworth.tennis.ui.components.FieldLabel
import io.github.wotworth.tennis.ui.components.FlowRowSimple
import io.github.wotworth.tennis.ui.components.SectionHeader
import io.github.wotworth.tennis.ui.components.SmallAction
import io.github.wotworth.tennis.ui.components.TextBox
import io.github.wotworth.tennis.ui.components.TextRow
import io.github.wotworth.tennis.ui.theme.LocalZpx
import io.github.wotworth.tennis.ui.theme.TennisText
import io.github.wotworth.tennis.ui.theme.TennisTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Decoded photos kept in memory (about 24 MB at most), so tiles redraw at once. */
object PhotoCache {
    private val cache = object : android.util.LruCache<String, Bitmap>(24 * 1024 * 1024) { override fun sizeOf(key: String, value: Bitmap) = value.byteCount }
    fun get(name: String, maxSide: Int): Bitmap? = cache.get("$name@$maxSide")
    fun load(c: android.content.Context, name: String, maxSide: Int): Bitmap? =
        get(name, maxSide) ?: Photos.decode(Photos.file(c, name), maxSide)?.also { cache.put("$name@$maxSide", it) }
}

/** A photo file decoded off the main thread (or from [PhotoCache] at once), or null. */
@Composable
fun photoBitmap(name: String?, maxSide: Int = 720): Bitmap? {
    val c = LocalContext.current
    val b by produceState(name?.let { PhotoCache.get(it, maxSide) }, name) { value = name?.let { n -> withContext(Dispatchers.IO) { PhotoCache.load(c, n, maxSide) } } }
    return b
}

/**
 * NAV-02 (PH-4): the package photo behind the setup tile, darkened so the white text keeps its
 * contrast (VIS-04; scrim tunable).
 */
@Composable
fun PhotoBehind(name: String?): (@Composable BoxScope.() -> Unit)? {
    val b = photoBitmap(name) ?: return null
    return {
        Image(b.asImageBitmap(), null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = TennisTokens.Photos.scrim)))
    }
}

/**
 * PHO-01, PHO-02, PHO-10, PHO-20, PHO-21: one string's package photo: take or choose it; it is
 * read on the phone at once and fills the string's fields; "retry with Claude" asks Claude.
 */
@Composable
fun PackagePhoto(
    title: String,
    photo: String?,
    onPhoto: (String?) -> Unit,
    onRead: (StringSpec) -> Unit,
    startCamera: Boolean = false,
) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val zpx = LocalZpx.current
    val scope = rememberCoroutineScope()
    val known = appData().strings.map { it.spec.model }
    var status by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<String?>(null) }

    fun readOnPhone(name: String) = scope.launch {
        status = "reading the package…"
        status = runCatching {
            val text = Photos.readText(ctx, Photos.file(ctx, name))
            val spec = PackageText.read(text, known)
            if (spec.isBlank) "Couldn't read it. Type it in, or tap retry with Claude." else { onRead(spec); "Read on the phone. Check the fields below." }
        }.getOrElse { "Couldn't read it: ${it.message}" }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val name = pending ?: return@rememberLauncherForActivityResult
        if (ok) { onPhoto(name); readOnPhone(name) } else Photos.file(ctx, name).delete()
        pending = null
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch { val n = Photos.importPicked(ctx, uri); onPhoto(n); readOnPhone(n) }
    }
    fun takePhoto() { val (name, uri) = Photos.newCapture(ctx); pending = name; camera.launch(uri) }
    LaunchedEffect(startCamera) { if (startCamera && photo == null) takePhoto() }

    FieldLabel(title)
    Row(horizontalArrangement = Arrangement.spacedBy(zpx(12f))) {
        val b = photoBitmap(photo, 360)
        if (b != null) Image(b.asImageBitmap(), "package photo", contentScale = ContentScale.Crop, modifier = Modifier.size(zpx(TennisTokens.Layout.tileSmall * 1.4f)))
        Column {
            FlowRowSimple(gap = zpx(16f)) {
                SmallAction(if (photo == null) "take photo" else "retake") { takePhoto() }
                SmallAction("choose photo") { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
                if (photo != null) {
                    SmallAction("read again") { readOnPhone(photo) }
                    SmallAction("retry with Claude") {
                        val key = runCatching { ApiKeyStore(app).get() }.getOrNull()
                        when {
                            key.isNullOrBlank() -> status = "Add your Anthropic API key in settings to use this."
                            !ClaudeReader.online(ctx) -> status = "Needs an internet connection."
                            else -> scope.launch {
                                status = "asking Claude…"
                                val r = withContext(Dispatchers.IO) {
                                    val jpeg = Photos.forClaude(Photos.file(ctx, photo)) ?: return@withContext ClaudeReader.Result.Failed("The photo can't be opened.")
                                    ClaudeReader.read(key, jpeg)
                                }
                                status = when (r) {
                                    is ClaudeReader.Result.Read -> { onRead(r.spec); "Read by Claude. Check the fields below." }
                                    is ClaudeReader.Result.Failed -> r.message
                                }
                            }
                        }
                    }
                    SmallAction("remove") { onPhoto(null); status = null }
                }
            }
        }
    }
    status?.let { Spacer(Modifier.height(zpx(4f))); TennisText(it, TennisTokens.Type.listSecondary) }
    Spacer(Modifier.height(zpx(12f)))
}

/** PHO-02: fills the read fields over the form's, keeping what the photo didn't say. */
fun StringSpec.fillFrom(r: StringSpec) = StringSpec(
    r.brand.ifBlank { brand }, r.model.ifBlank { model }, r.gauge.ifBlank { gauge }, r.material.ifBlank { material },
)

/** The restring form's photo section: mains, and crosses for a hybrid (PHO-02). */
@Composable
fun RestringPhotos(j: StringJob, startCamera: Boolean, set: (StringJob) -> Unit) {
    PackagePhoto(if (j.hybrid) "mains package photo" else "package photo", j.mainsPhoto, { set(j.copy(mainsPhoto = it)) }, { set(j.copy(mains = j.mains.fillFrom(it))) }, startCamera)
    if (j.hybrid) PackagePhoto("crosses package photo", j.crossesPhoto, { set(j.copy(crossesPhoto = it)) }, { set(j.copy(crossesOwn = j.crossesOwn.fillFrom(it))) })
}

/** PHO-22: the API key in settings: only its last four characters are ever shown. */
@Composable
fun ApiKeySection() {
    val app = LocalApp.current
    val store = remember { ApiKeyStore(app) }
    var hint by remember { mutableStateOf(runCatching { store.hint() }.getOrNull()) }
    var typing by remember { mutableStateOf("") }
    SectionHeader("package photos")
    if (hint != null) {
        TextRow("Anthropic API key …$hint", "Used only for \"retry with Claude\". Tap to remove it.") { store.clear(); hint = null }
    } else {
        TextBox("Anthropic API key (for \"retry with Claude\")", typing, { typing = it.trim() })
        if (typing.length > 20) TextRow("save key", "Kept encrypted on this phone; never exported or shown again") {
            runCatching { store.set(typing) }; typing = ""; hint = runCatching { store.hint() }.getOrNull()
        }
    }
}
